//
//  ChildProcessTransport.swift
//  mcp-swift-sdk
//
//  Created by Eric on 4/18/25.
//



import Logging

import Foundation
import class Foundation.Pipe
import struct Foundation.Data

#if canImport(System)
	import System
#else
	@preconcurrency import SystemPackage
#endif

// Import for specific low-level operations not yet in Swift System
#if canImport(Darwin)
	import Darwin.POSIX
#elseif canImport(Glibc)
	import Glibc
#endif

#if canImport(Darwin) || canImport(Glibc)


public actor ChilProcessTransport: Transport {

	public var logger: Logging.Logger

	/// command: The executable to run to start the server.
	var command: String

	/// arguments: Command line arguments to pass to the executable.
	var arguments: [String]?

	// The environment to use when spawning the process.
	// If not specified, the result of getDefaultEnvironment() will be used.
	var environment: [String: String]?

	// The working directory to use when spawning the process.
	// If not specified, the current working directory will be inherited.
	var cwd : String?
	
	fileprivate var stdioTransport: StdioTransport?
	fileprivate var process: Process?

	private var isConnected = false
	
	public init(
		 command: String,
		 arguments: [String]? = nil,
		 environment: [String: String]? = nil,
		 logger: Logger? = nil
	) {
		self.command = command
		self.arguments = arguments
		self.environment = environment
		self.logger = logger ?? Logger(
				label: "mcp.transport.stdio.process",
   			factory: { _ in SwiftLogNoOpLogHandler() })
	
	}
	
	public func connect() async throws {
		guard !isConnected else { return }

		let input = Pipe()
		let output = Pipe()
		
		self.stdioTransport = StdioTransport(
			input: FileDescriptor(rawValue: output.fileHandleForReading.fileDescriptor),
			output: FileDescriptor(rawValue: input.fileHandleForWriting.fileDescriptor),
			logger: logger)
		
		let process = Process()
		process.standardInput = input
		process.standardOutput = output
		process.executableURL = URL(fileURLWithPath: self.command)
		process.arguments = self.arguments
		process.environment = environment ?? ProcessInfo.processInfo.environment
		try process.run()
		logger.info("Child process spawned successfully")
		try await self.stdioTransport?.connect()
	}

	public func disconnect() async {
		if let stdioTransport {
			await stdioTransport.disconnect()
			self.stdioTransport = nil
		}
	}
	
	public func send(_ data: Data) async throws {
		if let stdioTransport {
			try await stdioTransport.send(data)
		}
	}
	
	public func receive() -> AsyncThrowingStream<Data, Swift.Error> {
		if let stdioTransport {//TODO
			return stdioTransport.receive()
		}
		return AsyncThrowingStream { }
	}
}

#endif
