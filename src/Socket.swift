// Socket.swift
// Copyright (c) 2024 ssh2.app
// Created by admin@ssh2.app 2024/8/15.

import CSSH
import Darwin
import Foundation

public extension SSH {
    // 属性用于检查套接字是否已连接
    var isConnected: Bool {
        guard sockfd != -1 else {
            return false
        }
        var optval: Int32 = 0
        var optlen: socklen_t = Darwin.socklen_t(MemoryLayout<Int32>.size)
        let result = withUnsafeMutablePointer(to: &optval) {
            getsockopt(sockfd, SOL_SOCKET, SO_ERROR, $0, &optlen)
        }
        return result == 0 && optval == 0
    }

    /// 连接到指定的套接字文件描述符。
    /// - Parameter sockfd: 套接字文件描述符的整数值。
    /// - Returns: 如果连接成功返回true，如果文件描述符无效（例如-1）则返回false。
    func connect(sockfd: Int32) async -> Bool {
        await call {
            guard sockfd != -1 else {
                return false
            }
            self.sockfd = sockfd
            return self.isConnected
        }
    }

    /// 连接到服务器的异步函数。
    /// 该函数尝试创建一个套接字并连接到服务器。
    /// 如果套接字创建成功，则保存套接字文件描述符并返回true。
    /// 如果套接字创建失败，则返回false。
    func connect() async -> Bool {
        await call {
            self.closeSocket()
            let sockfd = self.create()
            guard sockfd != -1 else {
                return false
            }
            self.sockfd = sockfd
            return self.isConnected
        }
    }

    /// 创建并配置socket的函数，返回socket文件描述符。
    /// - Returns: 成功时返回socket文件描述符，失败时返回-1。
    private func create() -> Int32 {
        var hints = Darwin.addrinfo()
        hints.ai_family = AF_UNSPEC
        hints.ai_socktype = SOCK_STREAM
        hints.ai_flags = AI_ADDRCONFIG | AI_CANONNAME
        hints.ai_protocol = IPPROTO_TCP

        var addrInfo: UnsafeMutablePointer<addrinfo>?
        let portString = String(port)
        let result = Darwin.getaddrinfo(host, portString, &hints, &addrInfo)
        guard result == 0, let addr = addrInfo else {
            return -1
        }

        defer {
            Darwin.freeaddrinfo(addrInfo)
        }

        var sockfd: Int32 = -1
        for info in sequence(first: addr, next: { $0?.pointee.ai_next }) {
            guard let info else {
                continue
            }
            sockfd = Darwin.socket(info.pointee.ai_family, info.pointee.ai_socktype, info.pointee.ai_protocol)
            if sockfd < 0 {
                continue
            }

            var timeoutStruct = Darwin.timeval(tv_sec: timeout, tv_usec: 0)
            setsockopt(sockfd, SOL_SOCKET, SO_SNDTIMEO, &timeoutStruct, socklen_t(MemoryLayout<timeval>.size))
            setsockopt(sockfd, SOL_SOCKET, SO_RCVTIMEO, &timeoutStruct, socklen_t(MemoryLayout<timeval>.size))

            if Darwin.connect(sockfd, info.pointee.ai_addr, info.pointee.ai_addrlen) == 0 {
                break
            }

            Darwin.close(sockfd)
            sockfd = -1
        }

        return sockfd
    }

    /**
     发送数据到socket
     - Parameters:
       - socket: 要发送数据的socket
       - buffer: 包含要发送数据的缓冲区
       - length: 要发送的数据长度
       - flags: 发送标志
     - Returns: 成功发送的字节数，如果发送失败则返回错误码
     */
    func send(socket: libssh2_socket_t, buffer: UnsafeRawPointer, length: size_t, flags: CInt) -> Int {
        let size = Darwin.send(socket, buffer, length, flags)
        if size < 0 {
            return Int(-errno)
        }
        addOperation {
            await self.sessionDelegate?.send(ssh: self, size: size)
        }
        return size
    }

    /**
     从socket接收数据
     - Parameters:
       - socket: 要接收数据的socket
       - buffer: 用于存储接收数据的缓冲区
       - length: 要接收的最大数据长度
       - flags: 接收标志
     - Returns: 成功接收的字节数，如果接收失败则返回错误码
     */
    func recv(socket: libssh2_socket_t, buffer: UnsafeMutableRawPointer, length: size_t, flags: CInt) -> Int {
        let size = Darwin.recv(socket, buffer, length, flags)
        if size < 0 {
            return Int(-errno)
        }
        addOperation {
            await self.sessionDelegate?.recv(ssh: self, size: size)
        }
        return size
    }

    /// 等待套接字变为可读或可写状态
    /// - Returns: 返回select函数的返回值，-1表示错误，0表示超时，大于0表示就绪的文件描述符数量
    func waitsocket() -> Int32 {
        // 检查rawSession是否存在以及sockfd是否有效
        guard let rawSession, sockfd != -1 else {
            return -1
        }

        // 设置超时时间
        var timeout = Darwin.timeval(tv_sec: self.timeout, tv_usec: 0)

        // 初始化文件描述符集合
        var fdSet, readFd, writeFd: Darwin.fd_set
        fdSet = Darwin.fd_set()
        readFd = Darwin.fd_set()
        writeFd = Darwin.fd_set()
        fdSet.zero()
        fdSet.set(sockfd)
        readFd.zero()
        writeFd.zero()

        // 获取会话阻塞方向
        let dir = libssh2_session_block_directions(rawSession)

        // 如果会话阻塞在入站方向
        if (dir & LIBSSH2_SESSION_BLOCK_INBOUND) != 0 {
            readFd = fdSet
        }

        // 如果会话阻塞在出站方向
        if (dir & LIBSSH2_SESSION_BLOCK_OUTBOUND) != 0 {
            writeFd = fdSet
        }

        let rc = Darwin.select(sockfd + 1, &readFd, &writeFd, nil, &timeout)

        #if DEBUG
            print("阻塞:\(rc) dir: \(dir)")
        #endif

        return rc
    }

    /**
     关闭Socket连接
     */
    func closeSocket() {
        shutdown()
        Darwin.close(sockfd)
        sockfd = -1
    }

    /**
     使用指定的方式关闭Socket
     - Parameter how: 关闭方式，默认为SHUT_RDWR，表示同时关闭读和写
     */
    func shutdown(_ how: Int32 = SHUT_RDWR) {
        // 调用Darwin库的shutdown函数
        Darwin.shutdown(sockfd, how)
    }
}

// 定义每个fd_set可以容纳的文件描述符数量
let __fd_set_count = Int(__DARWIN_FD_SETSIZE) / 32

public extension Darwin.fd_set {
    // 内联函数，用于计算文件描述符在fd_set中的位置和掩码
    @inline(__always)
    private static func address(for fd: Int32) -> (Int, Int32) {
        let intOffset = Int(fd) / __fd_set_count
        let bitOffset = Int(fd) % __fd_set_count
        let mask = Int32(bitPattern: UInt32(1 << bitOffset))
        return (intOffset, mask)
    }

    /// 将fd_set中的所有位设置为0
    mutating func zero() {
        withCArrayAccess { $0.initialize(repeating: 0, count: __fd_set_count) }
    }

    /// 在fd_set中设置一个文件描述符
    /// - Parameter fd: 要添加到fd_set的文件描述符
    mutating func set(_ fd: Int32) {
        let (index, mask) = fd_set.address(for: fd)
        withCArrayAccess { $0[index] |= mask }
    }

    /// 从fd_set中清除一个文件描述符
    /// - Parameter fd: 要从fd_set中清除的文件描述符
    mutating func clear(_ fd: Int32) {
        let (index, mask) = fd_set.address(for: fd)
        withCArrayAccess { $0[index] &= ~mask }
    }

    /// 检查fd_set中是否存在一个文件描述符
    /// - Parameter fd: 要检查的文件描述符
    /// - Returns: 如果存在返回`True`，否则返回`false`
    mutating func isSet(_ fd: Int32) -> Bool {
        let (index, mask) = fd_set.address(for: fd)
        return withCArrayAccess { $0[index] & mask != 0 }
    }

    // 内联函数，用于获取对fd_set内部数组的安全访问
    @inline(__always)
    internal mutating func withCArrayAccess<T>(block: (UnsafeMutablePointer<Int32>) throws -> T) rethrows -> T {
        return try withUnsafeMutablePointer(to: &fds_bits) {
            try block(UnsafeMutableRawPointer($0).assumingMemoryBound(to: Int32.self))
        }
    }
}
