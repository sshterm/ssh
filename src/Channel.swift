// Channel.swift
// Copyright (c) 2024 ssh2.app
// Created by admin@ssh2.app 2024/8/16.

import CSSH
import Foundation

public extension SSH {
    /// 打开一个新的SSH通道
    /// - Parameter lang: 可选的语言环境变量，默认为空
    /// - Returns: 如果通道打开成功返回true，否则返回false
    func openChannel(lang: String = "") async -> Bool {
        await call {
            self.close(.channel)
            let rawChannel = self.callSSH2 {
                (self.rawSession != nil) ? libssh2_channel_open_ex(self.rawSession, "session", 7, 2 * 1024 * 1024, 32768, nil, 0) : nil
            }
            if !lang.isEmpty {
                _ = self.callSSH2 {
                    guard let rawChannel = self.rawChannel else {
                        return -1
                    }
                    return libssh2_channel_setenv_ex(rawChannel, "LANG", 4, lang, lang.countUInt32)
                }
            }
            self.rawChannel = rawChannel
            return true
        }
    }

    /// 设置环境变量
    /// - Parameters:
    ///   - name: 环境变量的名称
    ///   - value: 环境变量的值
    /// - Returns: 如果设置成功返回true，否则返回false
    func setenv(name: String, value: String) async -> Bool {
        await call {
            let code = self.callSSH2 {
                guard let rawChannel = self.rawChannel else {
                    return -1
                }
                return libssh2_channel_setenv_ex(rawChannel, name, name.countUInt32, value, value.countUInt32)
            }
            guard code == LIBSSH2_ERROR_NONE else {
                return false
            }
            return true
        }
    }

    // 定义isRead属性，当通道未接收到EOF（文件结束符）、未接收到退出信号且连接状态为真时，返回true
    var isRead: Bool {
        !(receivedEOF || receivedExit)
    }

    /// 执行给定的命令，并异步返回标准输出和标准错误的数据。
    /// - Parameter command: 要执行的命令字符串。
    /// - Returns: 一个元组，包含标准输出数据和标准错误数据。
    func exec(command: String) async -> (stdout: Data?, dtderr: Data?) {
        guard await openChannel() else {
            return (nil, nil)
        }
        var stdout = Data()
        var dtderr = Data()
        guard await exec(command: command, { d in
            stdout.append(d)
            return true
        }, { d in
            dtderr.append(d)
            return true
        }) else {
            return (nil, nil)
        }
        return (stdout, dtderr)
    }

    // exec 函数用于执行一个命令，并通过回调函数处理标准输出和错误输出。
    // 参数:
    // - command: 要执行的命令字符串
    // - callout: 一个闭包，当接收到标准输出数据时调用，返回一个布尔值表示是否继续处理
    // - callerr: 一个闭包，当接收到错误输出数据时调用，返回一个布尔值表示是否继续处理
    // 返回值: 一个异步的布尔值，表示命令执行是否成功
    func exec(command: String, _ callout: @escaping (Data) -> Bool, _ callerr: @escaping (Data) -> Bool) async -> Bool {
        guard await openChannel() else {
            return false
        }
        var ok = true

        return await withUnsafeContinuation { continuation in
            let code = self.callSSH2 {
                guard let rawChannel = self.rawChannel else {
                    return -1
                }
                return libssh2_channel_process_startup(rawChannel, "exec", 4, command, command.countUInt32)
            }
            guard code == LIBSSH2_ERROR_NONE else {
                self.close(.channel)
                continuation.resume(returning: false)
                return
            }
            self.channelBlocking(false)
            self.cancelSources()

            self.socketSource = DispatchSource.makeReadSource(fileDescriptor: self.sockfd, queue: self.queue)
            self.socketSource?.setEventHandler {
                self.lockRow.lock()
                defer {
                    self.lockRow.unlock()
                }
                repeat {
                    let (stdout, rc, dtderr, erc) = self.read()
                    guard rc > 0 || erc > 0 else {
                        guard rc != LIBSSH2_ERROR_SOCKET_RECV || erc != LIBSSH2_ERROR_SOCKET_RECV else {
                            ok = false
                            self.cancelSources()
                            return
                        }
                        break
                    }
                    if rc > 0 {
                        if !callout(stdout) {
                            self.cancelSources()
                            return
                        }
                    } else if erc > 0 {
                        if !callerr(dtderr) {
                            self.cancelSources()
                            return
                        }
                    }
                    if self.receivedEOF || !self.isConnected {
                        self.cancelSources()
                        return
                    }
                } while self.isPol()
                if !self.isRead {
                    self.cancelSources()
                    return
                }
            }
            self.socketSource?.setCancelHandler {
                self.lockRow.lock()
                defer {
                    self.lockRow.unlock()
                }
                #if DEBUG
                    print("轮询socket关闭")
                #endif
                _ = self.sendEOF()
                self.close(.channel)
                continuation.resume(returning: ok)
            }
            self.socketSource?.resume()
        }
    }

    /// 打开一个SSH子系统，并异步返回操作是否成功。
    /// - Parameter name: 要打开的子系统的名称。
    /// - Returns: 如果子系统成功打开则返回true，否则返回false。
    func subsystem(name: String) async -> Bool {
        await call {
            let code = self.callSSH2 {
                guard let rawChannel = self.rawChannel else {
                    return -1
                }
                return libssh2_channel_process_startup(rawChannel, "subsystem", 9, name, name.countUInt32)
            }
            guard code == LIBSSH2_ERROR_NONE else {
                return false
            }
            return true
        }
    }

    // write 方法用于向通道写入数据，可以选择是否写入标准错误流。
    // - 参数:
    //   - data: 要写入的数据
    //   - stderr: 如果为 true，则数据将被写入标准错误流，默认为 false
    // - 返回值: 如果写入成功返回 true，否则返回 false
    func write(data: Data, stderr: Bool = false) async -> Bool {
        await call {
            let code = self.callSSH2 {
                guard let rawChannel = self.rawChannel else {
                    return -1
                }
                return libssh2_channel_write_ex(rawChannel, stderr ? SSH_EXTENDED_DATA_STDERR : 0, data.pointerCChar, data.count)
            }
            guard code > 0 else {
                return false
            }
            return true
        }
    }

    /// 从通道读取数据，可以选择是否读取错误信息和是否等待数据。
    /// - Parameters:
    ///   - err: 是否读取错误信息，默认为false。
    ///   - wait: 是否等待数据，默认为true。
    /// - Returns: 返回一个元组，包含读取的数据和读取的字节数。如果没有数据可读或者通道已关闭，返回空的Data和-1。
    func read(err: Bool = false, wait: Bool = true) -> (Data, Int) {
        let buflen = bufferSize
        let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: buflen)
        defer {
            buffer.deallocate()
        }
        let rc = callSSH2(wait) {
            guard let rawChannel = self.rawChannel else {
                return -1
            }
            return libssh2_channel_read_ex(rawChannel, err ? SSH_EXTENDED_DATA_STDERR : 0, buffer, buflen)
        }
        return (rc > 0 ? Data(bytes: buffer, count: rc) : .init(), rc)
    }

    /// 同时读取正常数据和错误数据的函数。
    /// - Returns: 一个元组，包含正常数据、正常数据的错误码、错误数据和错误数据的错误码。
    func read() -> (Data, Int, Data, Int) {
        var rc, erc: Int
        var data, dataer: Data
        (data, rc) = read(wait: false)
        (dataer, erc) = read(err: true, wait: false)
        return (data, rc, dataer, erc)
    }

    /// 检查从SSH通道接收数据的状态。
    /// - Parameter stderr: 如果为true，则检查标准错误流的数据；否则，检查标准输出流的数据。
    /// - Returns: 如果成功接收到数据，则返回true；否则返回false。
    func isPol(_ stderr: Bool = false) -> Bool {
        guard let rawChannel = rawChannel else {
            return false
        }
        return libssh2_poll_channel_read(rawChannel, stderr ? SSH_EXTENDED_DATA_STDERR : 0) != 0
    }

    // 判断是否接收到退出状态
    var receivedExit: Bool {
        guard let rawChannel else {
            return false
        }
        return libssh2_channel_get_exit_status(rawChannel) != 0
    }

    // 判断是否接收到EOF（文件结束标记）
    var receivedEOF: Bool {
        guard let rawChannel else {
            return false
        }
        return libssh2_channel_eof(rawChannel) != 0
    }

    // 发送EOF到远程服务器
    func sendEOF() -> Bool {
        guard !receivedEOF else {
            return true
        }
        let code = callSSH2 {
            guard let rawChannel = self.rawChannel else {
                return -1
            }
            return libssh2_channel_send_eof(rawChannel)
        }
        guard code == LIBSSH2_ERROR_NONE else {
            return false
        }
        return true
    }

    // 设置通道的阻塞状态
    /// 设置当前SSH通道是否为阻塞模式。
    /// - Parameter blocking: 布尔值，`true`表示设置为阻塞模式，`false`表示设置为非阻塞模式。
    func channelBlocking(_ blocking: Bool) {
        if let rawChannel {
            libssh2_channel_set_blocking(rawChannel, blocking ? 1 : 0)
        }
    }

    // 取消所有定时器和socket源
    /// 取消当前所有的定时器和socket事件源。
    func cancelSources() {
        #if DEBUG
            print("取消所有定时器和socket源")
        #endif
        if let socketSource = socketSource {
            socketSource.cancel()
            self.socketSource = nil
        }
    }
}
