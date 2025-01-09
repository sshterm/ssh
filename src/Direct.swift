// Direct.swift
// Copyright (c) 2025 ssh2.app
// Created by admin@ssh2.app 2024/8/23.

import CSSH
import Foundation

public extension SSH {
    // tcpip 方法用于通过 TCP/IP 连接创建一个 SSH 通道
    // - 参数:
    //   - host: 目标主机地址
    //   - port: 目标主机端口
    //   - shost: 告知 SSH 服务器连接发起的主机
    //   - sport: 告知 SSH 服务器连接源自的端口
    // - 返回值: 如果成功创建通道返回 true，否则返回 false
    func tcpip(host: String, port: Int32, shost: String, sport: Int32) async -> Bool {
        await call {
            guard let rawSession = self.rawSession else {
                return false
            }
            self.close(.channel)
            let rawChannel = self.callSSH2 {
                libssh2_channel_direct_tcpip_ex(rawSession, host, port, shost, sport)
            }
            guard let rawChannel else {
                return false
            }
            self.rawChannel = rawChannel
            return true
        }
    }

    // streamlocal 方法用于通过本地套接字创建一个 SSH 通道
    // - 参数:
    //   - socketpath: 服务器本地套接字路径
    //   - shost: 告知 SSH 服务器连接发起的主机
    //   - sport: 告知 SSH 服务器连接源自的端口
    // - 返回值: 如果成功创建通道返回 true，否则返回 false
    func streamlocal(socketpath: String, shost: String, sport: Int32) async -> Bool {
        await call {
            guard let rawSession = self.rawSession else {
                return false
            }
            self.close(.channel)
            let rawChannel = self.callSSH2 {
                libssh2_channel_direct_streamlocal_ex(rawSession, socketpath, shost, sport)
            }
            guard let rawChannel else {
                return false
            }
            self.rawChannel = rawChannel
            return true
        }
    }
}
