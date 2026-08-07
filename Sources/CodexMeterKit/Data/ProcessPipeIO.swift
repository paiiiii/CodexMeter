import Darwin
import Foundation

enum ProcessPipeReadOutcome: Equatable, Sendable {
  case endOfFile
  case cancelled
  case failed
}

final class ProcessPipeReader: @unchecked Sendable {
  private enum Event: Sendable {
    case data(Data)
    case endOfFile
    case cancelled
    case failed
  }

  private static let chunkSize = 64 * 1_024

  private let source: any DispatchSourceRead
  private let continuation: AsyncStream<Event>.Continuation
  private let events: AsyncStream<Event>

  init(handle: FileHandle, label: String) {
    let (events, continuation) = AsyncStream<Event>.makeStream(
      bufferingPolicy: .bufferingOldest(64)
    )
    let descriptor = handle.fileDescriptor
    let queue = DispatchQueue(
      label: "com.codexmeter.process-pipe-reader.\(label)",
      qos: .utility
    )
    let source = DispatchSource.makeReadSource(
      fileDescriptor: descriptor,
      queue: queue
    )

    self.events = events
    self.continuation = continuation
    self.source = source

    source.setEventHandler { [weak source] in
      guard let source else { return }
      let requestedCount = Int(
        min(max(source.data, 1), UInt(ProcessPipeReader.chunkSize))
      )
      var data = Data(count: requestedCount)
      var count: Int
      var readError: Int32 = 0
      repeat {
        count = data.withUnsafeMutableBytes { buffer -> Int in
          guard let baseAddress = buffer.baseAddress else { return 0 }
          return Darwin.read(descriptor, baseAddress, buffer.count)
        }
        readError = count == -1 ? errno : 0
      } while count == -1 && readError == EINTR

      if count > 0 {
        data.removeSubrange(count..<data.count)
        if case .dropped = continuation.yield(.data(data)) {
          continuation.finish()
          source.cancel()
        }
      } else if count == 0 {
        continuation.yield(.endOfFile)
        continuation.finish()
        source.cancel()
      } else if readError != EAGAIN {
        continuation.yield(.failed)
        continuation.finish()
        source.cancel()
      }
    }

    source.setCancelHandler {
      try? handle.close()
      continuation.finish()
    }
    continuation.onTermination = { @Sendable [weak source] _ in
      source?.cancel()
    }
    source.resume()
  }

  func read(
    onData: @escaping @Sendable (Data) async -> Void
  ) async -> ProcessPipeReadOutcome {
    for await event in events {
      switch event {
      case .data(let data):
        guard !Task.isCancelled else { return .cancelled }
        await onData(data)
      case .endOfFile:
        return Task.isCancelled ? .cancelled : .endOfFile
      case .cancelled:
        return .cancelled
      case .failed:
        return Task.isCancelled ? .cancelled : .failed
      }
    }

    return Task.isCancelled ? .cancelled : .endOfFile
  }

  func cancel() {
    continuation.yield(.cancelled)
    continuation.finish()
    source.cancel()
  }

  deinit {
    source.cancel()
  }
}

enum ProcessPipeIO {
  static func suppressSIGPIPE(on handle: FileHandle) throws {
    guard fcntl(handle.fileDescriptor, F_SETNOSIGPIPE, 1) != -1 else {
      throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
  }
}
