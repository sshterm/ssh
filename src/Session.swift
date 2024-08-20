// Session.swift
// Copyright (c) 2024 ssh2.app
// Created by admin@ssh2.app 2024/8/16.

import Darwin
import Foundation

// 定义SessionDelegate协议，包含SSH会话相关的回调方法
public protocol SessionDelegate {
    /// 当SSH会话断开时调用
    func disconnect(ssh: SSH)

    /// 当SSH会话握手时调用
    func connect(ssh: SSH)

    /// 当需要键盘交互时调用，返回用户输入的字符串
    func keyboardInteractive(ssh: SSH, prompt: String) -> String

    /// 发送数据时调用，参数为发送数据的大小
    func send(ssh: SSH, size: Int)

    /// 接收数据时调用，参数为接收数据的大小
    func recv(ssh: SSH, size: Int)

    /// 输出调试信息
    func debug(ssh: SSH, message: String)
}

// 定义ChannelDelegate协议，包含SSH通道相关的回调方法
public protocol ChannelDelegate {
    // 标准输出数据到达时调用
    func stdout(ssh: SSH, data: Data)
    // 标准错误输出数据到达时调用
    func dtderr(ssh: SSH, data: Data)
    // 通道断开时调用
    func disconnect(ssh: SSH)
    // 通道连接时调用
    func connect(ssh: SSH, online: Bool)
}

// 定义C语言风格的函数类型别名
typealias sendType = @convention(c) (libssh2_socket_t, UnsafeRawPointer, size_t, CInt, UnsafeRawPointer) -> ssize_t
typealias recvType = @convention(c) (libssh2_socket_t, UnsafeMutableRawPointer, size_t, CInt, UnsafeRawPointer) -> ssize_t
typealias disconnectType = @convention(c) (UnsafeRawPointer, CInt, UnsafePointer<CChar>, CInt, UnsafePointer<CChar>, CInt, UnsafeRawPointer) -> Void
typealias debugType = @convention(c) (UnsafeRawPointer, CInt, UnsafePointer<CChar>, CInt, UnsafePointer<CChar>, CInt, UnsafeRawPointer) -> Void
public extension SSH {
    /// 从给定的不安全原始指针中获取SSH实例。
    /// - Parameter abstract: 一个指向SSH实例的不安全原始指针。
    /// - Returns: 返回一个SSH实例。
    static func getSSH(from abstract: UnsafeRawPointer) -> SSH {
        let ptr = abstract.bindMemory(to: UnsafeRawPointer.self, capacity: 1)
        return Unmanaged<SSH>.fromOpaque(ptr.pointee).takeUnretainedValue()
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
            let debug: debugType = { sess, reason, message, messageLen, language, languageLen, abstract in
                SSH.getSSH(from: abstract).debug(sess: sess, reason: reason, message: message, messageLen: messageLen, language: language, languageLen: languageLen)
            }
            self.rawSession = libssh2_session_init_ex(nil, nil, nil, UnsafeMutableRawPointer(mutating: Unmanaged.passUnretained(self).toOpaque()))

            libssh2_trace(self.rawSession, self.debug.trace)
            libssh2_session_set_blocking(self.rawSession, self.blocking ? 1 : 0)
            libssh2_session_flag(self.rawSession, LIBSSH2_FLAG_COMPRESS, self.compress ? 1 : 0)
            libssh2_session_banner_set(self.rawSession, "SSH-2.0-libssh2_SSHTerm-6.2")
            libssh2_session_callback_set(self.rawSession, LIBSSH2_CALLBACK_DISCONNECT, unsafeBitCast(disconnect, to: UnsafeMutableRawPointer.self))
            libssh2_session_callback_set(self.rawSession, LIBSSH2_CALLBACK_SEND, unsafeBitCast(send, to: UnsafeMutableRawPointer.self))
            libssh2_session_callback_set(self.rawSession, LIBSSH2_CALLBACK_RECV, unsafeBitCast(recv, to: UnsafeMutableRawPointer.self))
            libssh2_session_callback_set(self.rawSession, LIBSSH2_CALLBACK_DEBUG, unsafeBitCast(debug, to: UnsafeMutableRawPointer.self))
            self.sessionTimeout = Int(self.timeout)
            let code = self.callSSH2 {
                libssh2_session_handshake(self.rawSession, self.sockfd)
            }
            guard code == LIBSSH2_ERROR_NONE else {
                self.closeSession()
                return false
            }
            self.addOperation {
                self.sessionDelegate?.connect(ssh: self)
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
                        let ssh = SSH.getSSH(from: abstract!)
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

    /// 计算并返回会话指纹
    /// - Parameter type: 指纹哈希类型，默认为.sha1
    /// - Returns: 返回计算得到的指纹字符串，如果出错则返回nil
    func fingerprint(_ type: FingerprintHashType = .sha1) async -> String? {
        await call {
            guard let rawSession = self.rawSession else {
                return nil
            }
            let hashPointer = libssh2_hostkey_hash(rawSession, type.hashType)
            guard let hashPointer else {
                return nil
            }
            let hash = UnsafeRawPointer(hashPointer).assumingMemoryBound(to: UInt8.self)
            return (0 ..< type.digest).map { String(format: "%02hhX", hash[$0]) }.joined(separator: ":")
        }
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

    // 关闭会话
    func closeSession() {
        addOperation {
            self.sessionDelegate?.disconnect(ssh: self)
        }
        shutdown(SHUT_RD)
        closeSFTP()
        closeChannel()

        if let rawSession {
            _ = callSSH2 {
                libssh2_session_disconnect_ex(rawSession, SSH_DISCONNECT_BY_APPLICATION, "SSH Term: Disconnect", "")
            }
            libssh2_session_free(rawSession)
        }
        rawSession = nil
    }
}
