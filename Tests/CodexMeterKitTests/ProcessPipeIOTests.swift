import Darwin
import Foundation
import XCTest

@testable import CodexMeterKit

final class ProcessPipeIOTests: XCTestCase {
  func testReaderDeliversDataUntilEndOfFile() async throws {
    let pipe = Pipe()
    let recorder = DataRecorder()
    let pipeReader = ProcessPipeReader(
      handle: pipe.fileHandleForReading,
      label: "test-eof"
    )
    let reader = Task {
      await pipeReader.read { data in
        await recorder.append(data)
      }
    }
    let payload = Data("first line\nsecond line\n".utf8)

    try pipe.fileHandleForWriting.write(contentsOf: payload)
    try pipe.fileHandleForWriting.close()

    let outcome = await reader.value
    let received = await recorder.data
    XCTAssertEqual(outcome, .endOfFile)
    XCTAssertEqual(received, payload)
  }

  func testReaderDeliversPartialChunkWhileWriterRemainsOpen() async throws {
    let pipe = Pipe()
    let delivered = expectation(description: "Partial pipe data delivered")
    let pipeReader = ProcessPipeReader(
      handle: pipe.fileHandleForReading,
      label: "test-partial"
    )
    let reader = Task {
      await pipeReader.read { _ in
        delivered.fulfill()
      }
    }

    try pipe.fileHandleForWriting.write(contentsOf: Data("response\n".utf8))
    await fulfillment(of: [delivered], timeout: 1)

    reader.cancel()
    pipeReader.cancel()
    let outcome = await reader.value
    XCTAssertEqual(outcome, .cancelled)
    try pipe.fileHandleForWriting.close()
  }

  func testClosingBlockedReadersAfterCancellationIsSafeUnderStress() async throws {
    for iteration in 0..<100 {
      let pipe = Pipe()
      let pipeReader = ProcessPipeReader(
        handle: pipe.fileHandleForReading,
        label: "test-stress"
      )
      let reader = Task {
        await pipeReader.read { _ in }
      }

      if iteration.isMultiple(of: 2) {
        await Task.yield()
      }
      reader.cancel()
      pipeReader.cancel()

      let outcome = await reader.value
      XCTAssertEqual(outcome, .cancelled, "Iteration \(iteration)")
      try pipe.fileHandleForWriting.close()
    }
  }

  func testSuppressedSIGPIPETurnsBrokenPipeWriteIntoAThrownError() throws {
    let pipe = Pipe()
    try ProcessPipeIO.suppressSIGPIPE(on: pipe.fileHandleForWriting)
    try pipe.fileHandleForReading.close()

    XCTAssertThrowsError(
      try pipe.fileHandleForWriting.write(contentsOf: Data([0x0A]))
    ) { error in
      let underlyingError = (error as NSError).userInfo[NSUnderlyingErrorKey] as? NSError
      XCTAssertEqual(underlyingError?.domain, NSPOSIXErrorDomain)
      XCTAssertEqual(underlyingError?.code, Int(EPIPE))
    }
    try pipe.fileHandleForWriting.close()
  }
}

private actor DataRecorder {
  private(set) var data = Data()

  func append(_ newData: Data) {
    data.append(newData)
  }
}
