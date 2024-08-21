// SCP.swift
// Copyright (c) 2024 ssh2.app
// Created by admin@ssh2.app 2024/8/21.

import CSSH
import Darwin
import Foundation

public extension SSH {
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

            guard let fileSize = self.getFileSize(filePath: localPath) else {
                return false
            }

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
}
