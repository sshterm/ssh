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

    // trace 函数用于记录消息，它接受一个 C 风格的字符串指针和字符串长度作为参数。
    // - Parameters:
    //   - message: 一个指向 C 风格字符串的 UnsafePointer，表示要记录的消息。
    //   - messageLen: 一个 Int 类型的值，表示消息的长度。
    func trace(message: UnsafePointer<CChar>, messageLen: Int) {
        guard let msg = String(data: Data(bytes: message, count: messageLen), encoding: .utf8) else {
            return
        }
        sessionDelegate?.trace(ssh: self, message: msg)
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
