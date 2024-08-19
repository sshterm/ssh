// Channel.swift
// Copyright (c) 2024 ssh2.app
// Created by admin@ssh2.app 2024/8/16.

import Darwin
import FileKit
import Foundation

public extension SSH {
    /// 打开一个新的SSH通道
    /// - Parameter lang: 可选的语言环境变量，默认为空
    /// - Returns: 如果通道打开成功返回true，否则返回false
    func openChannel(lang: String = "") async -> Bool {
        await call {
            guard let rawSession = self.rawSession else {
                return false
            }
            self.closeChannel()
            let rawChannel = self.callSSH2 {
                libssh2_channel_open_ex(rawSession, "session", 7, 2 * 1024 * 1024, 32768, nil, 0)
            }
            guard let rawChannel else {
                return false
            }
            if !lang.isEmpty {
                _ = self.callSSH2 {
                    libssh2_channel_setenv_ex(rawChannel, "LANG", 4, lang, lang.countUInt32)
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
            guard let rawChannel = self.rawChannel else {
                return false
            }
            let code = self.callSSH2 {
                libssh2_channel_setenv_ex(rawChannel, name, name.countUInt32, value, value.countUInt32)
            }
            guard code == LIBSSH2_ERROR_NONE else {
                return false
            }
            return true
        }
    }

    // 定义isRead属性，当通道未接收到EOF（文件结束符）、未接收到退出信号且连接状态为真时，返回true
    var isRead: Bool {
        !receivedEOF && !receivedExit && isConnected
    }

    /// 执行一个SSH命令，并异步返回命令执行结果的数据。
    /// - Parameter command: 要执行的SSH命令字符串。
    /// - Returns: 返回一个可选的Data类型，如果命令执行成功则包含输出数据，否则为nil。
    func exec(command: String) async -> Data? {
        guard await openChannel() else {
            return nil
        }
        defer {
            closeChannel()
        }
        return await read {
            guard let rawChannel = self.rawChannel else {
                return false
            }
            self.channelBlocking(false)
            let code = self.callSSH2 {
                libssh2_channel_process_startup(rawChannel, "exec", 4, command, command.countUInt32)
            }
            guard code == LIBSSH2_ERROR_NONE else {
                return false
            }
            return true
        }
    }

    /// 打开一个SSH子系统，并异步返回操作是否成功。
    /// - Parameter name: 要打开的子系统的名称。
    /// - Returns: 如果子系统成功打开则返回true，否则返回false。
    func subsystem(name: String) async -> Bool {
        await call {
            guard let rawChannel = self.rawChannel else {
                return false
            }
            let code = self.callSSH2 {
                libssh2_channel_process_startup(rawChannel, "subsystem", 9, name, name.countUInt32)
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
            guard let rawChannel = self.rawChannel else {
                return false
            }
            let code = self.callSSH2 {
                libssh2_channel_write_ex(rawChannel, stderr ? SSH_EXTENDED_DATA_STDERR : 0, data.pointerCChar, data.count)
            }
            guard code > 0 else {
                return false
            }
            return true
        }
    }

    // read 方法用于从通道读取数据，可以选择是否从标准错误流读取。
    // - 参数:
    //   - stderr: 如果为 true，则从标准错误流读取数据，默认为 false
    //   - call: 如果为 true，则使用调用方式读取数据，否则使用锁定方式读取数据，默认为 false
    // - 返回值: 读取到的数据，如果没有数据可读则返回空数据
    func read(_ stderr: Bool = false, call: Bool = false) -> Data {
        guard let rawChannel = rawChannel else {
            closeChannel()
            return .init()
        }
        let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: bufferSize)
        defer {
            buffer.deallocate()
        }
        var rc: Int
        if call {
            rc = callSSH2 {
                libssh2_channel_read_ex(rawChannel, stderr ? SSH_EXTENDED_DATA_STDERR : 0, buffer, self.bufferSize)
            }
        } else {
            lock.lock()
            rc = libssh2_channel_read_ex(rawChannel, stderr ? SSH_EXTENDED_DATA_STDERR : 0, buffer, bufferSize)
            lock.unlock()
        }
        guard rc > 0 else {
            return .init()
        }
        return Data(bytes: buffer, count: rc)
    }

    // read 方法是一个异步方法，用于从通道异步读取数据，可以选择是否从标准错误流读取，并提供一个回调函数。
    // - 参数:
    //   - stderr: 如果为 true，则从标准错误流读取数据，默认为 false
    //   - callback: 一个回调函数，用于决定是否继续读取数据
    // - 返回值: 读取到的数据，如果没有数据可读或者在回调函数返回 false 时取消读取，则返回 nil
    func read(stderr: Bool = false, callback: @escaping () -> Bool) async -> Data? {
        await withUnsafeContinuation { continuation in
            self.cancelSources()
            self.socketSource = DispatchSource.makeReadSource(fileDescriptor: self.sockfd, queue: self.queue)
            self.timeoutSource = DispatchSource.makeTimerSource(queue: self.queue)
            guard let socketSource = self.socketSource, let timeoutSource = self.timeoutSource else {
                continuation.resume(returning: nil)
                return
            }
            var data = Data()
            socketSource.setEventHandler {
                guard let timeoutSource = self.timeoutSource else {
                    self.closeChannel()
                    return
                }
                timeoutSource.suspend()
                defer {
                    timeoutSource.resume()
                }

                repeat {
                    let d = self.read(stderr, call: true)
                    if d.count > 0 {
                        data.append(d)
                    } else {
                        break
                    }
                } while true

                if !self.isRead {
                    self.cancelSources()
                }
            }
            socketSource.setCancelHandler {
                continuation.resume(returning: data)
                self.closeChannel()
            }

            timeoutSource.setEventHandler {
                self.cancelSources()
            }
            let timeout = TimeInterval(self.sessionTimeout)
            timeoutSource.schedule(deadline: .now() + timeout, repeating: timeout, leeway: .seconds(10))
            socketSource.resume()
            timeoutSource.resume()
            if !callback() {
                self.cancelSources()
            }
        }
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
        guard let rawChannel else {
            return false
        }
        let code = callSSH2 {
            libssh2_channel_send_eof(rawChannel)
        }
        guard code == LIBSSH2_ERROR_NONE else {
            return false
        }
        return true
    }

    /// 下载文件的异步函数，带进度回调
    /// - Parameters:
    ///   - remotePath: 远程文件路径
    ///   - localPath: 本地文件路径
    ///   - progress: 进度回调，接收已下载的总大小和文件总大小，返回一个布尔值表示是否继续下载
    /// - Returns: 下载是否成功的布尔值
    func download(remotePath: String, localPath: String, progress: @escaping (_ total: Int64, _ size: Int64) -> Bool) async -> Bool {
        await call {
            guard let rawSession = self.rawSession else {
                return false
            }
            self.closeChannel()
            var fileinfo = libssh2_struct_stat()
            self.rawChannel = self.callSSH2 {
                libssh2_scp_recv2(rawSession, remotePath, &fileinfo)
            }
            guard let rawChannel = self.rawChannel else {
                return false
            }
            let localFile = Darwin.open(localPath, O_WRONLY | O_CREAT | O_TRUNC, 0644)
            defer {
                Darwin.close(localFile)
                self.closeChannel()
            }
            let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: self.bufferSize)
            defer {
                buffer.deallocate()
            }
            var rc, n: Int
            var total: Int64 = 0
            while total < fileinfo.st_size {
                rc = self.callSSH2 {
                    libssh2_channel_read_ex(rawChannel, 0, buffer, self.bufferSize)
                }
                if rc > 0 {
                    n = Darwin.write(localFile, buffer, rc)

                    if n < rc {
                        return false
                    }
                    total += Int64(rc)
                    if !progress(total, fileinfo.st_size) {
                        return false
                    }
                } else if rc < 0 {
                    return false
                }
            }
            return true
        }
    }

    // 下载文件的异步函数，不带进度回调
    /// - Parameters:
    ///   - remotePath: 远程文件路径
    ///   - localPath: 本地文件路径
    /// - Returns: 下载是否成功的布尔值
    func download(remotePath: String, localPath: String) async -> Bool {
        await download(remotePath: remotePath, localPath: localPath) { _, _ in
            true
        }
    }

    // 上传文件的函数，支持异步操作和进度回调
    /// 使用默认权限上传本地文件到远程路径
    /// - Parameters:
    ///   - localPath: 本地文件路径
    ///   - remotePath: 远程文件路径
    ///   - Returns: 上传成功与否的布尔值
    func upload(localPath: String, remotePath: String, permissions: FilePermissions = .default) async -> Bool {
        await upload(localPath: localPath, remotePath: remotePath, permissions: permissions) { _, _ in
            true
        }
    }

    /// 上传本地文件到远程路径，支持自定义权限和进度回调
    /// - Parameters:
    ///   - localPath: 本地文件路径
    ///   - remotePath: 远程文件路径
    ///   - permissions: 文件权限，默认为默认权限
    ///   - progress: 进度回调，接收已上传的总字节数和文件总大小
    /// - Returns: 上传成功与否的布尔值
    func upload(localPath: String, remotePath: String, permissions: FilePermissions = .default, progress: @escaping (_ total: Int64, _ size: Int64) -> Bool) async -> Bool {
        await call {
            guard let rawSession = self.rawSession else {
                return false
            }
            guard let local = Darwin.fopen(localPath, "rb") else {
                return false
            }
            defer {
                Darwin.fclose(local)
            }
            let fileinfo = Path(rawValue: localPath)
            guard fileinfo.isRegular else {
                return false
            }
            guard let size = fileinfo.fileSize else {
                return false
            }
            let fileSize = Int64(size)
            self.closeChannel()
            self.rawChannel = self.callSSH2 {
                libssh2_scp_send64(rawSession, remotePath, permissions.rawValue, fileSize, 0, 0)
            }
            defer {
                self.closeChannel()
            }
            guard let rawChannel = self.rawChannel else {
                return false
            }
            var nread, rc: Int
            var total: Int64 = 0
            let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: self.bufferSize)
            defer {
                buffer.deallocate()
            }
            repeat {
                nread = Darwin.fread(buffer, 1, self.bufferSize, local)
                rc = self.callSSH2 {
                    libssh2_channel_write_ex(rawChannel, 0, buffer, nread)
                }
                if rc < 0 {
                    return false
                }
                total += Int64(rc)
                if !progress(total, fileSize) {
                    return false
                }
            } while nread > 0

            return true
        }
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
        if let timeoutSource = timeoutSource {
            timeoutSource.cancel()
            self.timeoutSource = nil
        }
        if let socketSource = socketSource {
            socketSource.cancel()
            self.socketSource = nil
        }
    }

    // 关闭SSH通道
    /// 关闭当前的SSH通道，并取消所有相关的事件源。
    func closeChannel() {
        cancelSources()
        if let rawChannel {
            _ = callSSH2 {
                libssh2_channel_send_eof(rawChannel)
            }
            _ = callSSH2 {
                libssh2_channel_close(rawChannel)
            }
            libssh2_channel_free(rawChannel)
            self.rawChannel = nil
        }
        addOperation {
            self.channelDelegate?.disconnect(ssh: self)
        }
    }
}
