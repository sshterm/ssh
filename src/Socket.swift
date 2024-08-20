// Socket.swift
// Copyright (c) 2024 ssh2.app
// Created by admin@ssh2.app 2024/8/15.

import Darwin
import Foundation
import Socket

public extension SSH {
    // 获取socket文件描述符，如果socket不存在则返回无效描述符
    var sockfd: Int32 {
        socket?.socketfd ?? Socket.SOCKET_INVALID_DESCRIPTOR
    }

    // 检查socket是否已连接
    var isConnected: Bool {
        socket?.isConnected ?? false
    }

    /**
     连接到指定的主机和端口
     - Returns: 如果连接成功返回true，否则返回false
     */
    func connect() async -> Bool {
        await call {
            do {
                let socket = try Socket.create(family: .unix)
                // try socket.setBlocking(mode: self.isBlocking)
                try socket.connect(to: self.host, port: self.port, timeout: UInt(self.timeout) * 1000)
                self.socket = socket
                guard self.sockfd != Socket.SOCKET_INVALID_DESCRIPTOR else {
                    return false
                }
                return true
            } catch {
                return false
            }
        }
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
            self.sessionDelegate?.send(ssh: self, size: size)
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
            self.sessionDelegate?.recv(ssh: self, size: size)
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
        var timeout = Darwin.timeval()
        timeout.tv_sec = self.timeout
        timeout.tv_usec = 0

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
        // 关闭Socket的读写操作
        shutdown()
        // 关闭socket并设置为nil
        socket?.close()
        socket = nil
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
