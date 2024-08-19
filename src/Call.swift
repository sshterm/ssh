// Call.swift
// Copyright (c) 2024 ssh2.app
// Created by admin@ssh2.app 2024/8/16.

import Foundation

extension SSH {
    /// 异步调用一个闭包，‌并返回其结果。‌
    /// - Parameter callback: 要异步执行的闭包。‌
    /// - Returns: 闭包执行的结果。‌
    func call<T>(_ callback: @escaping () -> T) async -> T {
        await withUnsafeContinuation { continuation in
            let ret = callback()
            continuation.resume(returning: ret)
        }
    }

    /// 调用一个返回`Int32`的闭包，‌并处理`LIBSSH2_ERROR_EAGAIN`错误。‌
    /// - Parameter callback: 要执行的闭包，‌返回`Int32`。‌
    /// - Returns: 闭包执行的结果。‌如果返回`LIBSSH2_ERROR_EAGAIN`，‌则可能会重试。‌
    func callSSH2(_ callback: @escaping () -> Int32) -> Int32 {
        var ret: Int32
        repeat {
            lock.lock()
            ret = callback()
            lock.unlock()
            guard ret == LIBSSH2_ERROR_EAGAIN else { break }
            guard waitsocket() > 0 else { break }
        } while true
        return ret
    }

    /// 调用一个返回`Int`的闭包，‌并处理`LIBSSH2_ERROR_EAGAIN`错误。‌
    /// - Parameter callback: 要执行的闭包，‌返回`Int`。‌
    /// - Returns: 闭包执行的结果。‌如果返回`LIBSSH2_ERROR_EAGAIN`，‌则可能会重试。‌
    func callSSH2(_ callback: @escaping () -> Int) -> Int {
        var ret: Int
        repeat {
            lock.lock()
            ret = callback()
            lock.unlock()
            guard ret == LIBSSH2_ERROR_EAGAIN else { break }
            guard waitsocket() > 0 else { break }
        } while true
        return ret
    }

    /// 调用一个返回可选类型`T?`的闭包，‌并处理`LIBSSH2_ERROR_EAGAIN`错误。‌
    /// - Parameter callback: 要执行的闭包，‌返回`T?`。‌
    /// - Returns: 闭包执行的结果。‌如果返回`nil`且错误为`LIBSSH2_ERROR_EAGAIN`，‌则可能会重试。‌
    func callSSH2<T>(_ callback: @escaping () -> T?) -> T? {
        var ret: T?
        repeat {
            lock.lock()
            ret = callback()
            lock.unlock()
            guard ret == nil, let rawSession, libssh2_session_last_errno(rawSession) == LIBSSH2_ERROR_EAGAIN else { break }
            guard waitsocket() > 0 else { break }
        } while true
        return ret
    }

    /// 向任务中添加一个操作，该操作会在执行时调用传入的闭包。
    /// - Parameter callback: 需要在操作执行时调用的闭包。
    func addOperation(_ callback: @escaping () -> Void) {
        let operation = BlockOperation {
            callback()
        }
        job.addOperation(operation)
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

    /// 调试信息输出函数
    /// - Parameters:
    ///   - sess: 会话指针
    ///   - reason: 原因代码
    ///   - message: 包含调试信息的C字符串指针
    ///   - messageLen: 调试信息字符串的长度
    ///   - language: 语言指针
    ///   - languageLen: 语言字符串的长度
    func debug(sess _: UnsafeRawPointer, reason _: CInt, message: UnsafePointer<CChar>, messageLen: CInt, language _: UnsafePointer<CChar>, languageLen _: CInt) {
        guard let msg = String(data: Data(bytes: message, count: Int(messageLen)), encoding: .utf8) else {
            return
        }
        addOperation {
            self.sessionDelegate?.debug(ssh: self, message: msg)
        }
    }

    /**
     断开与SSH会话的连接
     - Parameters:
       - sess: 会话的原始指针
       - reason: 断开原因的C语言整数
       - message: 包含断开消息的C字符指针
       - messageLen: 消息长度的C语言整数
       - language: 语言的C字符指针
       - languageLen: 语言长度的C语言整数
     */
    func disconnect(sess _: UnsafeRawPointer, reason _: CInt, message: UnsafePointer<CChar>, messageLen: CInt, language _: UnsafePointer<CChar>, languageLen _: CInt) {
        #if DEBUG
            let msg = Data(bytes: message, count: Int(messageLen))
            print("断开:\(msg)")
        #endif
        close()
    }
}
