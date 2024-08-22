// Call.swift
// Copyright (c) 2024 ssh2.app
// Created by admin@ssh2.app 2024/8/16.

import CSSH
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

    // callSSH2 函数用于执行 SSH2 调用，并根据 wait 参数决定是否等待。
    // 参数:
    // - wait: 一个布尔值，指示是否等待操作完成。
    // - callback: 一个闭包，执行后返回一个 Int32 类型的结果。
    // 返回值:
    // - Int32: 操作的结果代码。
    func callSSH2(_ wait: Bool = true, _ callback: @escaping () -> Int32) -> Int32 {
        var ret: Int32
        repeat {
            lock.lock()
            ret = callback()
            lock.unlock()
            guard wait, ret == LIBSSH2_ERROR_EAGAIN else { break }
            guard waitsocket() > 0 else { break }
        } while true
        return ret
    }

    // callSSH2 函数用于执行 SSH2 调用，可以选择是否等待操作完成，并通过回调函数返回结果。
    // 参数:
    // - wait: 一个布尔值，指示是否等待 SSH2 操作完成，默认为 true。
    // - callback: 一个闭包，执行后返回一个整数，表示操作的当前状态。
    // 返回值:
    // - 如果操作成功或不需要等待，则返回回调函数的结果；如果等待超时，则返回相应的错误代码。
    func callSSH2(_ wait: Bool = true, _ callback: @escaping () -> Int) -> Int {
        var ret: Int
        repeat {
            lock.lock()
            ret = callback()
            lock.unlock()
            guard wait, ret == LIBSSH2_ERROR_EAGAIN else { break }
            guard waitsocket() > 0 else { break }
        } while true
        return ret
    }

    // callSSH2 函数用于执行 SSH2 操作，并根据需要等待操作完成。
    // 参数:
    // - wait: 一个布尔值，指示是否应该等待操作完成。默认为 true。
    // - callback: 一个闭包，执行 SSH2 操作并返回一个可选的结果。
    // 返回值:
    // - 一个可选的结果类型 T?，如果操作成功完成则包含结果，否则为 nil。
    func callSSH2<T>(_ wait: Bool = true, _ callback: @escaping () -> T?) -> T? {
        var ret: T?
        repeat {
            lock.lock()
            ret = callback()
            lock.unlock()
            guard wait, ret == nil, let rawSession, libssh2_session_last_errno(rawSession) == LIBSSH2_ERROR_EAGAIN else { break }
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

    /// 向任务队列中添加一个操作，该操作会异步执行传入的回调函数。
    /// - Parameter callback: 一个异步闭包，将在BlockOperation中执行。
    func addOperation(_ callback: @escaping () async -> Void) {
        let operation = BlockOperation {
            Task {
                await callback()
            }
        }
        job.addOperation(operation)
    }

    #if DEBUG
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
                await self.sessionDelegate?.debug(ssh: self, message: msg)
            }
        }
    #endif

    // trace 函数用于记录消息，它接受一个 C 风格的字符串指针和字符串长度作为参数。
    // - Parameters:
    //   - message: 一个指向 C 风格字符串的 UnsafePointer，表示要记录的消息。
    //   - messageLen: 一个 Int 类型的值，表示消息的长度。
    func trace(message: UnsafePointer<CChar>, messageLen: Int) {
        guard let msg = String(data: Data(bytes: message, count: messageLen), encoding: .utf8) else {
            return
        }
        addOperation {
            await self.sessionDelegate?.trace(ssh: self, message: msg)
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
        sessionDelegate?.disconnect(ssh: self)
        close()
    }

    #if DEBUG
        public func disconnect() {
            close()
            sessionDelegate?.disconnect(ssh: self)
        }
    #endif
}
