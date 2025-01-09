// Auth.swift
// Copyright (c) 2025 ssh2.app
// Created by admin@ssh2.app 2024/11/30.

import CSSH
import Foundation

public extension SSH {
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
