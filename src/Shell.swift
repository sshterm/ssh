// Shell.swift
// Copyright (c) 2025 ssh2.app
// Created by admin@ssh2.app 2024/8/20.

import CSSH
import Foundation

public extension SSH {
    // 启动shell
    /// 启动一个新的shell会话是否成功
    /// - Returns: 如果启动成功返回true，否则返回false
    func shell() async -> Bool {
        await call {
            self.poll()
            let code = self.callSSH2 {
                guard let rawChannel = self.rawChannel else {
                    return -1
                }
                return libssh2_channel_process_startup(rawChannel, "shell", 5, nil, 0)
            }
            guard code == LIBSSH2_ERROR_NONE else {
                return false
            }
            self.addOperation {
                self.channelDelegate?.connect(ssh: self, online: true)
            }
            self.keepAlive()
            return true
        }
    }

    // 请求伪终端的大小
    /// 请求指定宽度和高度的伪终端大小是否成功
    /// - Parameters:
    ///   - width: 伪终端的宽度
    ///   - height: 伪终端的高度
    /// - Returns: 如果请求成功返回true，否则返回false
    func requestPtySize(width: Int32, height: Int32) async -> Bool {
        await call {
            let code = self.callSSH2 {
                guard let rawChannel = self.rawChannel else {
                    return -1
                }
                return libssh2_channel_request_pty_size_ex(rawChannel, width, height, LIBSSH2_TERM_WIDTH_PX, LIBSSH2_TERM_HEIGHT_PX)
            }
            guard code == LIBSSH2_ERROR_NONE else {
                return false
            }
            return true
        }
    }

    // 请求伪终端
    /// 请求指定类型和尺寸的伪终端是否成功
    /// - Parameters:
    ///   - type: 伪终端的类型，默认为.xterm
    ///   - width: 伪终端的宽度，默认为LIBSSH2_TERM_WIDTH
    ///   - height: 伪终端的高度，默认为LIBSSH2_TERM_HEIGHT
    /// - Returns: 如果请求成功返回true，否则返回false
    func requestPty(type: PtyType = .xterm, width: Int32 = LIBSSH2_TERM_WIDTH, height: Int32 = LIBSSH2_TERM_HEIGHT) async -> Bool {
        await call {
            let code = self.callSSH2 {
                guard let rawChannel = self.rawChannel else {
                    return -1
                }
                return libssh2_channel_request_pty_ex(rawChannel, type.rawValue, type.lengthUInt32, nil, 0, width, height, LIBSSH2_TERM_WIDTH_PX, LIBSSH2_TERM_HEIGHT_PX)
            }
            guard code == LIBSSH2_ERROR_NONE else {
                return false
            }
            return true
        }
    }

    /**
     * 暂停轮询
     * 该方法用于暂停当前的socket源轮询，停止接收新的数据。
     */
    func suspendPoll() {
        socketSource?.suspend()
    }

    /**
     * 恢复轮询
     * 该方法用于恢复之前暂停的socket源轮询，重新开始接收数据。
     */
    func resumePoll() {
        socketSource?.resume()
    }

    // poll方法用于轮询socket，读取标准输出和错误输出，并在适当的时候关闭通道。
    func poll() {
        channelBlocking(false)
        cancelSources()
        socketSource = DispatchSource.makeReadSource(fileDescriptor: sockfd, queue: queue)
        socketSource?.setEventHandler {
            self.lockRow.lock()
            defer {
                self.lockRow.unlock()
            }
            let (rc, erc) = self.read(PipeOutputStream(callback: { data in
                self.onData(data, true)
                return self.isPol(false)
            }), PipeOutputStream(callback: { data in
                self.onData(data, false)
                return self.isPol(true)
            }))
            guard rc > 0 || erc > 0 else {
                guard rc != LIBSSH2_ERROR_SOCKET_RECV || erc != LIBSSH2_ERROR_SOCKET_RECV else {
                    self.cancelSources()
                    return
                }
                return
            }
            if !self.isRead {
                self.cancelSources()
                return
            }
        }
        socketSource?.setCancelHandler {
            self.lockRow.lock()
            defer {
                self.lockRow.unlock()
            }
            #if DEBUG
                print("轮询socket关闭")
            #endif
            self.channelDelegate?.connect(ssh: self, online: false)
            _ = self.sendEOF()
            self.closeShell()
        }
        socketSource?.resume()
    }

    /// 关闭Shell的方法
    /// 该方法会断开SSH连接，取消所有操作源，并关闭通道
    func closeShell() {
        #if DEBUG
            print("关闭Shell", lastError?.localizedDescription ?? "")
        #endif
        job.cancelAllOperations()
        cancelSources()
        close(.channel)
    }

    /// 当接收到数据时调用此方法，根据stdout参数决定将数据发送到标准输出还是错误输出。
    /// - Parameters:
    ///   - data: 接收到的数据。
    ///   - stdout: 如果为true，数据将被发送到标准输出；如果为false，数据将被发送到错误输出。
    private func onData(_ data: Data, _ stdout: Bool) {
        guard data.count > 0 else {
            return
        }
        addOperation {
            await stdout ? self.channelDelegate?.stdout(ssh: self, data: data) : self.channelDelegate?.dtderr(ssh: self, data: data)
        }
    }
}
