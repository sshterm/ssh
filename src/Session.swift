// Session.swift
// Copyright (c) 2024 ssh2.app
// Created by admin@ssh2.app 2024/8/16.

import CSSH
import Darwin
import Foundation

public extension SSH {
    /// 从给定的不安全原始指针中获取SSH实例。
    /// - Parameter abstract: 一个指向SSH实例的不安全原始指针。
    /// - Returns: 返回一个SSH实例。
    static func getSSH(from abstract: UnsafeRawPointer) -> SSH {
        return abstract.bindMemory(to: SSH.self, capacity: 1).pointee
    }

    // 从原始会话指针中获取SSH会话对象
    // - 参数: rawSession - 原始的libssh2会话指针
    // - 返回: 如果成功获取到SSH会话对象，则返回SSH类型，否则返回nil
    static func getSSH(from rawSession: OpaquePointer?) -> SSH? {
        guard let abstract = libssh2_session_abstract(rawSession) else {
            return nil
        }
        return SSH.getSSH(from: abstract)
    }

    /// 检查服务器是否可用
    /// 该方法是检查后会释放会话
    /// - Returns: 如果服务器响应包含有效的SSH版本字符串，则返回true，否则返回false
    func checkServerAvaila() async -> Bool {
        guard await connect() else {
            return false
        }
        defer {
            self.close(.socket)
        }
        return await call {
            guard var c = "SSH-2.0-SSH2.app".trimmingCharacters(in: .whitespacesAndNewlines).data(using: .ascii) else {
                return false
            }
            c.append([0x0D, 0x0A], count: 2)
            guard io.Copy(InputStream(data: c), SocketOutput(self.sockfd)) > 0 else {
                return false
            }
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
            var data = Data()
            defer {
                buffer.deallocate()
            }
            for _ in 0 ... 3 {
                guard io.read(self.sockfd, buffer, 1) == 1 else {
                    return false
                }
                data.append(buffer, count: 1)
            }
            guard let versionString = String(data: data, encoding: .ascii), versionString == "SSH-" else {
                return false
            }
            return true
        }
    }

    // handshake函数用于初始化SSH会话并进行握手
    func handshake() async -> Bool {
        // await call {
        let disconnect: disconnectType = { sess, reason, message, messageLen, language, languageLen, abstract in
            SSH.getSSH(from: abstract).disconnect(sess: sess, reason: reason, message: message, messageLen: messageLen, language: language, languageLen: languageLen)
        }
        let send: sendType = { socket, buffer, length, flags, abstract in
            SSH.getSSH(from: abstract).send(socket: socket, buffer: buffer, length: length, flags: flags)
        }
        let recv: recvType = { socket, buffer, length, flags, abstract in
            SSH.getSSH(from: abstract).recv(socket: socket, buffer: buffer, length: length, flags: flags)
        }
        #if DEBUG
            let debug: debugType = { sess, reason, message, messageLen, language, languageLen, abstract in
                SSH.getSSH(from: abstract).debug(sess: sess, reason: reason, message: message, messageLen: messageLen, language: language, languageLen: languageLen)
            }
        #endif
        let trace: libssh2_trace_handler_func = { sess, _, message, messageLen in
            guard let message else {
                return
            }
            SSH.getSSH(from: sess)?.trace(message: message, messageLen: messageLen)
        }

        libssh2_init(0)
        rawSession = libssh2_session_init_ex(nil, nil, nil, Unmanaged.passUnretained(self).toOpaque())

        _ = methods.map { (key: SSHMethod, value: String) in
            libssh2_session_method_pref(self.rawSession, key.int32, value)
        }

        libssh2_trace(rawSession, self.debug.trace)
        libssh2_trace_sethandler(rawSession, nil, trace)
        libssh2_session_set_blocking(rawSession, blocking ? 1 : 0)
        libssh2_session_flag(rawSession, LIBSSH2_FLAG_COMPRESS, compress ? 1 : 0)
        libssh2_session_flag(rawSession, LIBSSH2_FLAG_SIGPIPE, 1)
        libssh2_session_flag(rawSession, LIBSSH2_FLAG_QUOTE_PATHS, 1)

        libssh2_session_set_timeout(rawSession, timeout * 1000)

        libssh2_session_banner_set(rawSession, banner.hasPrefix("SSH-2") ? banner : "SSH-2.0-libssh2_SSH2.app")
        libssh2_session_callback_set2(rawSession, LIBSSH2_CALLBACK_DISCONNECT, unsafeBitCast(disconnect, to: cbGenericType.self))
        libssh2_session_callback_set2(rawSession, LIBSSH2_CALLBACK_SEND, unsafeBitCast(send, to: cbGenericType.self))
        libssh2_session_callback_set2(rawSession, LIBSSH2_CALLBACK_RECV, unsafeBitCast(recv, to: cbGenericType.self))
        #if DEBUG
            libssh2_session_callback_set2(rawSession, LIBSSH2_CALLBACK_DEBUG, unsafeBitCast(debug, to: cbGenericType.self))
        #endif
        let code = callSSH2 {
            libssh2_session_handshake(self.rawSession, self.sockfd)
        }
        guard code == LIBSSH2_ERROR_NONE else {
            close(.session)
            return false
        }
        guard sessionDelegate?.connect(ssh: self, fingerprint: fingerprint() ?? "") ?? true else {
            close(.session)
            return false
        }
        return true
        // }
    }

    // 获取服务器横幅信息
    // 如果rawSession存在，则返回libssh2_session_banner_get函数获取的字符串，否则返回nil
    var serverBanner: String? {
        guard let rawSession else {
            return nil
        }
        return String(cString: libssh2_session_banner_get(rawSession))
    }

    // 设置和获取会话超时时间
    // 设置时，如果rawSession存在，则调用libssh2_session_set_timeout函数设置新的超时时间（单位转换为毫秒）
    // 获取时，如果rawSession存在，则调用libssh2_session_get_timeout函数获取超时时间，并将结果转换为秒
    var sessionTimeout: Int {
        set {
            if let rawSession {
                libssh2_session_set_timeout(rawSession, newValue * 1000)
            }
        }
        get {
            guard let rawSession else {
                return 0
            }

            return libssh2_session_get_timeout(rawSession) / 1000
        }
    }

    // 设置和获取SSH读取超时时间
    // 设置时，如果rawSession存在，则调用libssh2_session_set_read_timeout函数设置新的读取超时时间（单位转换为毫秒）
    // 获取时，如果rawSession存在，则调用libssh2_session_get_read_timeout函数获取读取超时时间，并将结果转换为秒
    var sshReadTimeout: Int {
        set {
            if let rawSession {
                libssh2_session_set_read_timeout(rawSession, newValue * 1000)
            }
        }
        get {
            guard let rawSession else {
                return 0
            }

            return libssh2_session_get_read_timeout(rawSession) / 1000
        }
    }

    /// 保持SSH会话活跃的函数。
    /// 该函数检查是否需要保持会话活跃，并且用户已认证。
    /// 如果是，则配置libssh2库的心跳机制，并设置一个定时器来定期发送心跳包。
    func keepAlive() {
        guard let rawSession, keepalive, isAuthenticated else {
            return
        }
        libssh2_keepalive_config(rawSession, 1, UInt32(keepaliveInterval))
        cancelKeepalive()
        keepAliveSource = DispatchSource.makeTimerSource(queue: .global(qos: .background))

        guard let keepAliveSource else {
            return
        }
        keepAliveSource.schedule(deadline: DispatchTime.now() + .seconds(keepaliveInterval), repeating: .seconds(keepaliveInterval), leeway: .seconds(keepaliveInterval))

        keepAliveSource.setEventHandler {
            self.sendKeepalive()
        }
        keepAliveSource.setCancelHandler {
            #if DEBUG
                print("心跳机制退出")
            #endif
            // self.close()
        }
        keepAliveSource.resume()
    }

    // 取消心跳包
    func cancelKeepalive() {
        keepAliveSource?.cancel()
        keepAliveSource = nil
    }

    // 发送心跳包以保持连接活跃
    private func sendKeepalive() {
        keepAliveSource?.suspend()
        defer {
            keepAliveSource?.resume()
        }
        guard let rawSession = rawSession else {
            keepAliveSource?.cancel()
            return
        }
        let seconds = UnsafeMutablePointer<UInt32>.allocate(capacity: 0)
        defer {
            seconds.deallocate()
        }
        let rc = libssh2_keepalive_send(rawSession, seconds)
        guard rc == LIBSSH2_ERROR_NONE else {
            if rc == LIBSSH2_ERROR_SOCKET_SEND {
                keepAliveSource?.cancel()
                // close()
            }
            return
        }
        #if DEBUG
            print("心跳秒", seconds.pointee)
        #endif
    }

    // 定义isBlocking属性，用于获取和设置会话的阻塞状态
    var isBlocking: Bool {
        set {
            if let rawSession {
                libssh2_session_set_blocking(rawSession, newValue ? 1 : 0)
            }
        }
        get {
            guard let rawSession else {
                return false
            }
            return libssh2_session_get_blocking(rawSession) == 1
        }
    }

    // 返回基于指定算法的主机密钥指纹
    /// - Parameter algorithm: 指定的哈希算法，默认为SHA1
    /// - Returns: 主机密钥的指纹字符串，如果无法生成则返回nil
    func fingerprint(_ algorithm: ShaAlgorithm = .sha1) -> String? {
        guard let key = hostkey() else {
            return nil
        }
        let data = Crypto.shared.sha(key.data, algorithm: algorithm)
        return data.fingerprint
    }

    /// 返回当前会话的主机密钥信息。
    /// 如果会话无效或无法获取主机密钥，则返回nil。
    func hostkey() -> Hostkey? {
        guard let rawSession = rawSession else {
            return nil
        }
        let len = UnsafeMutablePointer<Int>.allocate(capacity: 0)
        let type = UnsafeMutablePointer<Int32>.allocate(capacity: 0)
        defer {
            len.deallocate()
            type.deallocate()
        }
        guard let key = libssh2_session_hostkey(rawSession, len, type) else {
            return nil
        }
        return Hostkey(data: Data(bytes: key, count: len.pointee), type: HostkeyType(rawValue: type.pointee))
    }

    // isCompressed 属性用于检查会话是否被压缩。
    // 它通过检查压缩方法的字符串前缀是否为 "zlib" 来确定。
    // 如果会话的客户端到服务器（.comp_cs）或服务器到客户端（.comp_sc）的压缩方法都是以 "zlib" 开头，
    // 则认为会话是压缩的，返回 true；否则返回 false。
    var isCompressed: Bool {
        methods(.comp_cs)?.hasPrefix("zlib") ?? false && methods(.comp_sc)?.hasPrefix("zlib") ?? false
    }

    /// 返回指定类型的SSH协议字符串。
    /// - Parameter type: SSH方法的类型。
    /// - Returns: 如果成功获取到方法字符串，则返回该字符串，否则返回nil。
    func methods(_ type: SSHMethod) -> String? {
        guard let rawSession = rawSession else {
            return nil
        }
        guard let methods = libssh2_session_methods(rawSession, type.int32) else {
            return nil
        }
        return String(cString: methods)
    }

    /// 用户认证列表
    /// 该函数异步获取当前会话支持的用户认证方法列表。
    /// - Returns: 返回一个字符串数组，包含所有支持的用户认证方法。
    func userauth() async -> [String] {
        await call {
            guard let rawSession = self.rawSession else {
                return []
            }
            let ptr = self.callSSH2 {
                libssh2_userauth_list(rawSession, self.user, UInt32(self.user.count))
            }
            guard let ptr else {
                return []
            }
            return ptr.string.components(separatedBy: ",")
        }
    }

    // 最后一个错误
    /// 获取会话的最后一个错误信息。
    /// - Returns: NSError对象，如果无错误则返回nil。
    var lastError: NSError? {
        guard let rawSession else {
            return nil
        }
        var cstr: UnsafeMutablePointer<CChar>?

        let code = libssh2_session_last_error(rawSession, &cstr, nil, 0)
        guard code != LIBSSH2_ERROR_NONE else {
            return nil
        }
        guard let cstr else {
            return nil
        }
        return NSError(domain: "libssh2", code: Int(code), userInfo: [NSLocalizedDescriptionKey: cstr.string])
    }
}
