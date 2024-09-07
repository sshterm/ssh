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

    // handshake函数用于初始化SSH会话并进行握手
    func handshake() async -> Bool {
        await call {
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

            self.rawSession = libssh2_session_init_ex(nil, nil, nil, Unmanaged.passUnretained(self).toOpaque())

            _ = self.methods.map { (key: SSHMethod, value: String) in
                libssh2_session_method_pref(self.rawSession, key.int32, value)
            }

            libssh2_trace(self.rawSession, self.debug.trace)
            libssh2_trace_sethandler(self.rawSession, nil, trace)
            libssh2_session_set_blocking(self.rawSession, self.blocking ? 1 : 0)
            libssh2_session_flag(self.rawSession, LIBSSH2_FLAG_COMPRESS, self.compress ? 1 : 0)
            libssh2_session_flag(self.rawSession, LIBSSH2_FLAG_SIGPIPE, 1)
            libssh2_session_flag(self.rawSession, LIBSSH2_FLAG_QUOTE_PATHS, 1)

            libssh2_session_banner_set(self.rawSession, self.banner.isEmpty ? "SSH-2.0-libssh2_SSHTerm-6.0" : self.banner)
            #if V010b01
                libssh2_session_callback_set2(self.rawSession, LIBSSH2_CALLBACK_DISCONNECT, unsafeBitCast(disconnect, to: cbGenericType.self))
                libssh2_session_callback_set2(self.rawSession, LIBSSH2_CALLBACK_SEND, unsafeBitCast(send, to: cbGenericType.self))
                libssh2_session_callback_set2(self.rawSession, LIBSSH2_CALLBACK_RECV, unsafeBitCast(recv, to: cbGenericType.self))
                #if DEBUG
                    libssh2_session_callback_set2(self.rawSession, LIBSSH2_CALLBACK_DEBUG, unsafeBitCast(debug, to: cbGenericType.self))
                #endif
            #else
                libssh2_session_callback_set(self.rawSession, LIBSSH2_CALLBACK_DISCONNECT, unsafeBitCast(disconnect, to: UnsafeMutableRawPointer.self))
                libssh2_session_callback_set(self.rawSession, LIBSSH2_CALLBACK_SEND, unsafeBitCast(send, to: UnsafeMutableRawPointer.self))
                libssh2_session_callback_set(self.rawSession, LIBSSH2_CALLBACK_RECV, unsafeBitCast(recv, to: UnsafeMutableRawPointer.self))
                #if DEBUG
                    libssh2_session_callback_set(self.rawSession, LIBSSH2_CALLBACK_DEBUG, unsafeBitCast(debug, to: UnsafeMutableRawPointer.self))
                #endif
            #endif
            // self.sessionTimeout = Int(self.timeout)
            let code = self.callSSH2 {
                libssh2_session_handshake(self.rawSession, self.sockfd)
            }
            guard code == LIBSSH2_ERROR_NONE else {
                self.close(.session)
                return false
            }
            guard self.sessionDelegate?.connect(ssh: self, fingerprint: self.fingerprint() ?? "") ?? true else {
                self.close(.session)
                return false
            }
            return true
        }
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

    // 使用密码进行身份验证
    /// 使用提供的密码尝试进行SSH会话身份验证。
    /// - Parameter password: 要用于身份验证的密码字符串。
    /// - Returns: 如果身份验证成功则返回true，否则返回false。
    func authenticate(password: String) async -> Bool {
        guard let rawSession = rawSession else {
            return false
        }
        let list = await userauth()
        guard list.contains("password") else {
            return false
        }
        return await call {
            let code = self.callSSH2 {
                libssh2_userauth_password_ex(rawSession, self.user, self.user.countUInt32, password, password.countUInt32, nil)
            }
            guard code == LIBSSH2_ERROR_NONE, self.isAuthenticated else {
                return false
            }

            return true
        }
    }

    // 使用私钥文件进行身份验证
    /// 使用提供的私钥文件和可选的密码短语尝试进行SSH会话身份验证。
    /// - Parameters:
    ///   - privateKeyFile: 私钥文件的路径。
    ///   - passphrase: 可选的密码短语，用于解锁私钥。
    ///   - publickeyFile: 可选的公钥文件路径，默认为空字符串。
    /// - Returns: 如果身份验证成功则返回true，否则返回false。
    func authenticate(privateKeyFile: String, passphrase: String? = nil, publickeyFile: String = "") async -> Bool {
        guard let rawSession = rawSession else {
            return false
        }
        let list = await userauth()
        guard list.contains("publickey") else {
            return false
        }
        return await call {
            let code = self.callSSH2 {
                libssh2_userauth_publickey_fromfile_ex(rawSession, self.user, self.user.countUInt32, publickeyFile, privateKeyFile, passphrase)
            }
            guard code == LIBSSH2_ERROR_NONE, self.isAuthenticated else {
                return false
            }

            return true
        }
    }

    // 使用内存中的私钥进行身份验证
    /// 使用提供的内存中私钥和可选的密码短语尝试进行SSH会话身份验证。
    /// 如果提供了公钥，则使用该公钥；否则，将尝试使用默认值。
    /// - Parameters:
    ///   - privateKey: 内存中的私钥字符串。
    ///   - passphrase: 可选的密码短语，用于解锁私钥。
    ///   - publickey: 可选的公钥字符串，默认为空字符串。
    /// - Returns: 如果身份验证成功则返回true，否则返回false。
    func authenticate(privateKey: String, passphrase: String? = nil, publickey: String = "") async -> Bool {
        guard let rawSession = rawSession else {
            return false
        }
        let list = await userauth()
        guard list.contains("publickey") else {
            return false
        }
        return await call {
            let code = self.callSSH2 {
                libssh2_userauth_publickey_frommemory(rawSession, self.user, self.user.count, publickey, publickey.count, privateKey, privateKey.count, passphrase)
            }
            guard code == LIBSSH2_ERROR_NONE, self.isAuthenticated else {
                return false
            }

            return true
        }
    }

    /// 使用主机密钥认证方法对SSH会话进行身份验证。
    /// - Parameters:
    ///   - hostname: 远程主机名或IP地址。
    ///   - privateKeyFile: 私钥文件路径。
    ///   - passphrase: 私钥的密码（可选）。
    ///   - publickeyFile: 公钥文件路径（默认为空字符串，表示使用私钥文件中的公钥）。
    /// - Returns: 如果身份验证成功返回true，否则返回false。
    func authenticate(hostname: String, privateKeyFile: String, passphrase: String? = nil, publickeyFile: String = "") async -> Bool {
        guard let rawSession = rawSession else {
            return false
        }
        let list = await userauth()
        guard list.contains("hostbased") else {
            return false
        }
        return await call {
            let code = self.callSSH2 {
                libssh2_userauth_hostbased_fromfile_ex(rawSession, self.user, self.user.countUInt32, publickeyFile, privateKeyFile, passphrase, hostname, hostname.countUInt32, self.user, self.user.countUInt32)
            }
            guard code == LIBSSH2_ERROR_NONE, self.isAuthenticated else {
                return false
            }

            return true
        }
    }

    // 使用键盘交互进行身份验证
    /// 通过键盘交互方式进行SSH会话身份验证。
    /// 这种方法通常用于需要响应提示的情况，例如输入密码或PIN码。
    /// - Parameter none: 如果为true，则不使用无验证登录；如果为false，则使用键盘交互方式进行认证。
    /// - Returns: 返回一个布尔值，表示认证是否成功。
    func authenticate(_ none: Bool = false) async -> Bool {
        guard let rawSession = rawSession else {
            return false
        }
        if none {
            let list = await userauth()
            guard list.contains("none") else {
                return false
            }
            return isAuthenticated
        } else {
            let list = await userauth()
            guard list.contains("keyboard-interactive") else {
                return false
            }
            return await call {
                let code = self.callSSH2 {
                    libssh2_userauth_keyboard_interactive_ex(rawSession, self.user, self.user.countUInt32) { _, _, _, _, numPrompts, prompts, responses, abstract in
                        guard let abstract, let from = abstract.pointee else {
                            return
                        }
                        let ssh = SSH.getSSH(from: from)
                        for i in 0 ..< Int(numPrompts) {
                            guard let promptI = prompts?[i], let text = promptI.text else {
                                continue
                            }

                            let data = Data(bytes: UnsafeRawPointer(text), count: Int(promptI.length))

                            guard let challenge = String(data: data, encoding: .utf8) else {
                                continue
                            }

                            let password = ssh.sessionDelegate?.keyboardInteractive(ssh: ssh, prompt: challenge) ?? ""
                            let response = LIBSSH2_USERAUTH_KBDINT_RESPONSE(text: password.pointerCChar, length: password.countUInt32)
                            responses?[i] = response
                        }
                    }
                }
                guard code == LIBSSH2_ERROR_NONE else {
                    return false
                }
                return self.isAuthenticated
            }
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
            // self.close(.all)
        }
        keepAliveSource.resume()
    }

    // 取消心跳包
    func cancelKeepalive() {
        if let keepAliveSource = keepAliveSource {
            keepAliveSource.cancel()
            self.keepAliveSource = nil
        }
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
                // close(.session)
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

    // 是否认证
    /// 检查当前会话是否已经通过用户认证。
    /// - Returns: 如果用户已经认证则返回true，否则返回false。
    var isAuthenticated: Bool {
        guard let rawSession else {
            return false
        }
        return libssh2_userauth_authenticated(rawSession) == 1
    }
}
