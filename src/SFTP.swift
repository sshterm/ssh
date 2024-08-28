// SFTP.swift
// Copyright (c) 2024 ssh2.app
// Created by admin@ssh2.app 2024/8/17.

import CSSH
import Darwin
import Foundation

public extension SSH {
    // 打开SFTP会话
    /// 尝试初始化并打开一个SFTP会话。
    /// - Returns: 如果成功打开SFTP会话则返回true，否则返回false。
    func openSFTP() async -> Bool {
        await call {
            guard let rawSession = self.rawSession else {
                return false
            }
            self.close(.sftp)
            let rawSFTP = self.callSSH2 {
                libssh2_sftp_init(rawSession)
            }
            guard let rawSFTP else {
                return false
            }
            self.rawSFTP = rawSFTP
            return true
        }
    }

    // 打开指定路径的目录
    /// 异步打开并读取指定路径下的目录内容。
    /// - Parameter path: 要打开的目录路径，默认为根目录("/")。
    /// - Returns: 目录中文件的属性列表。
    func openDir(path: String = "/") async -> [FileAttributes] {
        await call {
            guard let rawSFTP = self.rawSFTP else {
                return []
            }
            let handle = self.callSSH2 {
                libssh2_sftp_open_ex(rawSFTP, path, path.countUInt32, UInt(LIBSSH2_FXF_READ), 0, LIBSSH2_SFTP_OPENDIR)
            }
            guard let handle else {
                return []
            }
            defer {
                libssh2_sftp_close_handle(handle)
            }
            var data: [FileAttributes] = []
            var rc: Int32
            let maxLen = 512
            let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: maxLen)
            let longEntry = UnsafeMutablePointer<CChar>.allocate(capacity: maxLen)
            defer {
                buffer.deallocate()
                longEntry.deallocate()
            }
            var attrs = LIBSSH2_SFTP_ATTRIBUTES()
            repeat {
                rc = self.callSSH2 {
                    libssh2_sftp_readdir_ex(handle, buffer, maxLen, longEntry, maxLen, &attrs)
                }
                if rc > 0 {
                    guard let name = String(data: Data(bytes: buffer, count: strlen(buffer)), encoding: .utf8),!self.ignoredFiles.contains(name) else {
                        continue
                    }
                    guard let longname = String(data: Data(bytes: longEntry, count: strlen(longEntry)), encoding: .utf8) else {
                        continue
                    }
                    data.append(FileAttributes(name: name, longname: longname, attributes: attrs))
                }
            } while rc > 0
            return data
        }
    }

    /// 判断SFTP操作是否出现错误
    /// - Returns: 如果出现错误返回true，否则返回false
    var isSFTPError: Bool {
        guard let rawSFTP = rawSFTP else {
            return true
        }
        return libssh2_sftp_last_error(rawSFTP) != LIBSSH2_FX_OK
    }

    /// 异步获取指定路径的文件系统状态信息
    /// - Parameter path: 文件系统路径，默认为根目录 "/"
    /// - Returns: 如果成功，返回 Statvfs 结构体，否则返回 nil
    func statvfs(path: String = "/") async -> Statvfs? {
        await call {
            guard let rawSFTP = self.rawSFTP else {
                return nil
            }
            var st = LIBSSH2_SFTP_STATVFS()
            let code = self.callSSH2 {
                libssh2_sftp_statvfs(rawSFTP, path, path.count, &st)
            }
            guard code == LIBSSH2_ERROR_NONE else {
                return nil
            }
            return Statvfs(statvfs: st)
        }
    }

    /// 异步获取指定路径的文件状态信息
    /// - Parameter path: 文件路径
    /// - Returns: 如果成功，返回 FileStat 结构体，否则返回 nil
    func stat(path: String) async -> FileStat? {
        await call {
            guard let rawSFTP = self.rawSFTP else {
                return nil
            }
            var st = LIBSSH2_SFTP_ATTRIBUTES()
            let code = self.callSSH2 {
                libssh2_sftp_stat_ex(rawSFTP, path, path.countUInt32, LIBSSH2_SFTP_STAT, &st)
            }
            guard code == LIBSSH2_ERROR_NONE else {
                return nil
            }
            return FileStat(attributes: st)
        }
    }

    // 读取符号链接的路径
    /// 该函数异步读取给定路径的符号链接目标路径。
    /// - Parameter path: 需要读取符号链接的文件或目录的路径。
    /// - Returns: 如果成功读取符号链接，则返回目标路径的字符串表示；否则返回nil。
    func readlink(path: String) async -> String? {
        await call {
            guard let rawSFTP = self.rawSFTP else {
                return nil
            }
            let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: self.bufferSize)
            defer {
                buffer.deallocate()
            }
            let rc = self.callSSH2 {
                libssh2_sftp_symlink_ex(rawSFTP, path, path.countUInt32, buffer, UInt32(self.bufferSize), LIBSSH2_SFTP_READLINK)
            }
            guard rc > 0 else {
                return nil
            }
            return String(data: Data(bytes: buffer, count: Int(rc)), encoding: .utf8)
        }
    }

    // 获取路径的真实路径
    /// 该函数异步获取给定路径的真实路径，解析任何符号链接。
    /// - Parameter path: 需要获取真实路径的文件或目录的路径。
    /// - Returns: 如果成功获取真实路径，则返回该路径的字符串表示；否则返回nil。
    func realpath(path: String) async -> String? {
        await call {
            guard let rawSFTP = self.rawSFTP else {
                return nil
            }
            let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: self.bufferSize)
            defer {
                buffer.deallocate()
            }
            let rc = self.callSSH2 {
                libssh2_sftp_symlink_ex(rawSFTP, path, path.countUInt32, buffer, UInt32(self.bufferSize), LIBSSH2_SFTP_REALPATH)
            }
            guard rc > 0 else {
                return nil
            }
            return String(data: Data(bytes: buffer, count: Int(rc)), encoding: .utf8)
        }
    }

    /// 创建目录
    /// - Parameters:
    ///   - path: 要创建的目录路径
    ///   - permissions: 目录权限，默认为默认权限
    /// - Returns: 如果目录创建成功返回true，否则返回false
    func mkdir(path: String, permissions: FilePermissions = .default) async -> Bool {
        await call {
            guard let rawSFTP = self.rawSFTP else {
                return false
            }
            let rc = self.callSSH2 {
                libssh2_sftp_mkdir_ex(rawSFTP, path, path.countUInt32, permissions.rawInt)
            }
            guard rc == LIBSSH2_ERROR_NONE else {
                return false
            }
            return true
        }
    }

    /// 创建文件
    /// - Parameters:
    ///   - path: 要创建的文件路径
    ///   - permissions: 文件权限，默认为默认权限
    /// - Returns: 如果文件创建成功返回true，否则返回false
    func mkfile(path: String, permissions: FilePermissions = .default) async -> Bool {
        await call {
            guard let rawSFTP = self.rawSFTP else {
                return false
            }
            let handle = self.callSSH2 {
                libssh2_sftp_open_ex(rawSFTP, path, path.countUInt32, UInt(LIBSSH2_FXF_WRITE | LIBSSH2_FXF_CREAT | LIBSSH2_FXF_TRUNC), permissions.rawInt, LIBSSH2_SFTP_OPENFILE)
            }
            guard let handle else {
                return false
            }
            libssh2_sftp_close_handle(handle)
            return true
        }
    }

    /// 重命名文件或目录
    /// - Parameters:
    ///   - orig: 原文件或目录路径
    ///   - newname: 新的文件或目录路径
    /// - Returns: 如果重命名成功返回true，否则返回false
    func rename(orig: String, newname: String) async -> Bool {
        await call {
            guard let rawSFTP = self.rawSFTP else {
                return false
            }
            let rc = self.callSSH2 {
                libssh2_sftp_rename_ex(rawSFTP, orig, orig.countUInt32, newname, newname.countUInt32, Int(LIBSSH2_SFTP_RENAME_OVERWRITE | LIBSSH2_SFTP_RENAME_ATOMIC | LIBSSH2_SFTP_RENAME_NATIVE))
            }
            guard rc == LIBSSH2_ERROR_NONE else {
                return false
            }
            return true
        }
    }

    /// 删除目录
    /// - Parameter path: 要删除的目录路径
    /// - Returns: 如果目录删除成功返回true，否则返回false
    func rmdir(path: String) async -> Bool {
        await call {
            guard let rawSFTP = self.rawSFTP else {
                return false
            }
            let rc = self.callSSH2 {
                libssh2_sftp_rmdir_ex(rawSFTP, path, path.countUInt32)
            }
            guard rc == LIBSSH2_ERROR_NONE else {
                return false
            }
            return true
        }
    }

    /// 删除文件
    /// - Parameter path: 要删除的文件路径
    /// - Returns: 如果文件删除成功返回true，否则返回false
    func unlink(path: String) async -> Bool {
        await call {
            guard let rawSFTP = self.rawSFTP else {
                return false
            }
            let rc = self.callSSH2 {
                libssh2_sftp_unlink_ex(rawSFTP, path, path.countUInt32)
            }
            guard rc == LIBSSH2_ERROR_NONE else {
                return false
            }
            return true
        }
    }

    /// 创建符号链接
    /// - Parameters:
    ///   - orig: 原文件或目录路径
    ///   - linkpath: 符号链接的路径
    /// - Returns: 如果符号链接创建成功返回true，否则返回false
    func symlink(orig: String, linkpath: String) async -> Bool {
        await call {
            guard let rawSFTP = self.rawSFTP else {
                return false
            }
            let rc = self.callSSH2 {
                libssh2_sftp_symlink_ex(rawSFTP, orig, orig.countUInt32, linkpath.pointerCChar, linkpath.countUInt32, LIBSSH2_SFTP_SYMLINK)
            }
            guard rc == LIBSSH2_ERROR_NONE else {
                return false
            }
            return true
        }
    }

    // chown 函数用于更改 SFTP 上文件或目录的所有者和权限。
    // 第一个重载版本接受路径、用户 ID (uid) 和组 ID (gid) 作为参数。
    ///
    /// - Parameters:
    ///   - path: 要更改所有者的文件或目录的路径。
    ///   - uid: 新的用户 ID。
    ///   - gid: 新的组 ID。
    /// - Returns: 如果操作成功则返回 true，否则返回 false。
    func chown(path: String, uid: UInt, gid: UInt) async -> Bool {
        await call {
            guard let rawSFTP = self.rawSFTP else {
                return false
            }
            var attrs = LIBSSH2_SFTP_ATTRIBUTES(flags: UInt(LIBSSH2_SFTP_ATTR_UIDGID), filesize: 0, uid: uid, gid: gid, permissions: 0, atime: 0, mtime: 0)
            let rc = self.callSSH2 {
                libssh2_sftp_stat_ex(rawSFTP, path, path.countUInt32, LIBSSH2_SFTP_SETSTAT, &attrs)
            }
            guard rc == LIBSSH2_ERROR_NONE else {
                return false
            }
            return true
        }
    }

    // 第二个重载版本接受路径和 FilePermissions 枚举作为参数。
    ///
    /// - Parameters:
    ///   - path: 要更改权限的文件或目录的路径。
    ///   - permissions: 新的文件权限。
    /// - Returns: 如果操作成功则返回 true，否则返回 false。
    func chown(path: String, permissions: FilePermissions) async -> Bool {
        await call {
            guard let rawSFTP = self.rawSFTP else {
                return false
            }
            var attrs = LIBSSH2_SFTP_ATTRIBUTES(flags: UInt(LIBSSH2_SFTP_ATTR_PERMISSIONS), filesize: 0, uid: 0, gid: 0, permissions: permissions.rawUInt, atime: 0, mtime: 0)
            let rc = self.callSSH2 {
                libssh2_sftp_stat_ex(rawSFTP, path, path.countUInt32, LIBSSH2_SFTP_SETSTAT, &attrs)
            }
            guard rc == LIBSSH2_ERROR_NONE else {
                return false
            }
            return true
        }
    }

    // 读取SFTP服务器上的文件内容
    // - 参数path: 文件路径
    // - 参数progress: 进度回调，返回已读取的总字节数和文件总大小
    // - 返回值: 文件内容的Data对象，如果失败则返回nil
    func readfile(path: String, progress: @escaping (_ total: Int, _ size: Int) -> Bool) async -> Data? {
        await call {
            guard let rawSFTP = self.rawSFTP else {
                return nil
            }
            var fileinfo = LIBSSH2_SFTP_ATTRIBUTES()
            let code = self.callSSH2 {
                libssh2_sftp_stat_ex(rawSFTP, path, path.countUInt32, LIBSSH2_SFTP_STAT, &fileinfo)
            }
            guard code == LIBSSH2_ERROR_NONE else {
                return nil
            }
            let handle = self.callSSH2 {
                libssh2_sftp_open_ex(rawSFTP, path, path.countUInt32, UInt(LIBSSH2_FXF_READ), 0, LIBSSH2_SFTP_OPENFILE)
            }
            guard let handle else {
                return nil
            }
            defer {
                libssh2_sftp_close_handle(handle)
            }
            let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: self.bufferSize)
            defer {
                buffer.deallocate()
            }
            var data = Data()
            var rc: Int
            var total = 0
            let filesize = Int(fileinfo.filesize)

            while total < filesize {
                rc = self.callSSH2 {
                    libssh2_sftp_read(handle, buffer, self.bufferSize)
                }
                if rc > 0 {
                    data.append(Data(bytes: buffer, count: rc))
                    total += rc
                    if !progress(total, filesize) {
                        return nil
                    }
                } else if rc < 0 {
                    return nil
                }
            }
            return data
        }
    }

    // 简化版的readfile函数，不接受进度回调，默认一直读取到文件结束
    // - 参数path: 文件路径
    // - 返回值: 文件内容的Data对象，如果失败则返回nil
    func readfile(path: String) async -> Data? {
        await readfile(path: path) { _, _ in
            true
        }
    }

    // 读取远程文件并将其保存到本地路径
    // - Parameters:
    //   - remotePath: 远程文件路径
    //   - localPath: 本地保存路径
    //   - progress: 进度回调，返回已下载的总大小和文件总大小
    // - Returns: 如果成功读取并保存文件则返回true，否则返回false
    func readfile(remotePath: String, localPath: String, progress: @escaping (_ total: Int64, _ size: Int64) -> Bool) async -> Bool {
        await call {
            guard let rawSFTP = self.rawSFTP else {
                return false
            }
            var fileinfo = LIBSSH2_SFTP_ATTRIBUTES()
            let code = self.callSSH2 {
                libssh2_sftp_stat_ex(rawSFTP, remotePath, remotePath.countUInt32, LIBSSH2_SFTP_STAT, &fileinfo)
            }
            guard code == LIBSSH2_ERROR_NONE else {
                return false
            }
            let handle = self.callSSH2 {
                libssh2_sftp_open_ex(rawSFTP, remotePath, remotePath.countUInt32, UInt(LIBSSH2_FXF_READ), 0, LIBSSH2_SFTP_OPENFILE)
            }
            guard let handle else {
                return false
            }
            defer {
                libssh2_sftp_close_handle(handle)
            }
            let localFile = Darwin.open(localPath, O_WRONLY | O_CREAT | O_TRUNC, 0644)
            defer {
                Darwin.close(localFile)
            }
            let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: self.bufferSize)
            defer {
                buffer.deallocate()
            }
            let filesize = Int64(fileinfo.filesize)
            var rc, n: Int
            var total: Int64 = 0
            while total < filesize {
                rc = self.callSSH2 {
                    libssh2_sftp_read(handle, buffer, self.bufferSize)
                }
                if rc > 0 {
                    n = Darwin.write(localFile, buffer, rc)

                    if n < rc {
                        return false
                    }
                    total += Int64(rc)
                    if !progress(total, filesize) {
                        return false
                    }
                } else if rc < 0 {
                    return false
                }
            }
            return true
        }
    }

    // 重载readfile函数，使用默认的进度回调
    // - Parameters:
    //   - remotePath: 远程文件路径
    //   - localPath: 本地保存路径
    // - Returns: 如果成功读取并保存文件则返回true，否则返回false
    func readfile(remotePath: String, localPath: String) async -> Bool {
        await readfile(remotePath: remotePath, localPath: localPath) { _, _ in
            true
        }
    }

    // 写入文件到SFTP服务器，使用Data类型的数据
    /// 将数据写入指定路径的文件中
    /// - Parameters:
    ///   - path: 远程文件路径
    ///   - data: 要写入的数据
    ///   - permissions: 文件权限，默认为默认权限
    ///   - progress: 进度回调，返回已写入的总字节数和文件总大小
    /// - Returns: 写入成功返回true，否则返回false
    func writefile(path: String, data: Data, permissions: FilePermissions = .default, progress: @escaping (_ total: Int, _ size: Int) -> Bool) async -> Bool {
        await call {
            guard let rawSFTP = self.rawSFTP else {
                return false
            }
            let handle = self.callSSH2 {
                libssh2_sftp_open_ex(rawSFTP, path, path.countUInt32, UInt(LIBSSH2_FXF_WRITE | LIBSSH2_FXF_CREAT | LIBSSH2_FXF_TRUNC), permissions.rawInt, LIBSSH2_SFTP_OPENFILE)
            }
            guard let handle else {
                return false
            }
            defer {
                libssh2_sftp_close_handle(handle)
            }

            var left = data.count
            var offset = 0
            let size = data.count

            repeat {
                let ret = data.withUnsafeBytes { ptr -> Int in
                    guard let rawBytes = ptr.bindMemory(to: Int8.self).baseAddress else {
                        return -1
                    }
                    return self.callSSH2 {
                        libssh2_sftp_write(handle, rawBytes.advanced(by: offset), left)
                    }
                }
                if ret > 0 {
                    left -= Int(ret)
                    offset += Int(ret)
                    if !progress(offset, size) {
                        return false
                    }
                } else if ret < 0 {
                    return false
                }
            } while left > 0

            return true
        }
    }

    /// 获取指定文件的大小，如果文件不存在或是一个目录，则返回nil。
    /// - Parameter filePath: 文件的路径
    /// - Returns: 文件的大小（以字节为单位），如果文件不存在或是一个目录，则返回nil。
    func getFileSize(filePath: String) -> Int64? {
        let fileManager = FileManager.default
        var fileSize: Int64?
        var isDir: ObjCBool = false
        if fileManager.fileExists(atPath: filePath, isDirectory: &isDir) {
            if !isDir.boolValue {
                if let attr = try? fileManager.attributesOfItem(atPath: filePath) {
                    fileSize = attr[FileAttributeKey.size] as? Int64
                }
            }
        }
        return fileSize
    }

    // 写入本地文件到SFTP服务器
    /// 将本地文件上传到SFTP服务器的指定路径
    /// - Parameters:
    ///   - localPath: 本地文件路径
    ///   - remotePath: 远程文件路径
    ///   - permissions: 文件权限，默认为默认权限
    ///   - progress: 进度回调，返回已上传的总字节数和文件总大小
    /// - Returns: 上传成功返回true，否则返回false
    func writefile(localPath: String, remotePath: String, permissions: FilePermissions = .default, progress: @escaping (_ total: Int64, _ size: Int64) -> Bool) async -> Bool {
        await call {
            guard let rawSFTP = self.rawSFTP else {
                return false
            }
            guard let local = Darwin.fopen(localPath, "rb") else {
                return false
            }
            defer {
                Darwin.fclose(local)
            }
            let handle = self.callSSH2 {
                libssh2_sftp_open_ex(rawSFTP, remotePath, remotePath.countUInt32, UInt(LIBSSH2_FXF_WRITE | LIBSSH2_FXF_CREAT | LIBSSH2_FXF_TRUNC), permissions.rawInt, LIBSSH2_SFTP_OPENFILE)
            }
            guard let handle else {
                return false
            }
            defer {
                libssh2_sftp_close_handle(handle)
            }
            guard let fileSize = self.getFileSize(filePath: localPath) else {
                return false
            }
            var nread, rc: Int
            var total: Int64 = 0
            let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: self.bufferSize)
            defer {
                buffer.deallocate()
            }
            while total < fileSize {
                nread = Darwin.fread(buffer, 1, self.bufferSize, local)
                rc = self.callSSH2 {
                    libssh2_sftp_write(handle, buffer, nread)
                }
                if rc < 0 {
                    return false
                }
                total += Int64(rc)
                if !progress(total, fileSize) {
                    return false
                }
            }

            return true
        }
    }

    // 写入本地文件到SFTP服务器，不显示进度
    /// 将本地文件上传到SFTP服务器的指定路径，不显示上传进度
    /// - Parameters:
    ///   - localPath: 本地文件路径
    ///   - remotePath: 远程文件路径
    ///   - permissions: 文件权限，默认为默认权限
    /// - Returns: 上传成功返回true，否则返回false
    func writefile(localPath: String, remotePath: String, permissions: FilePermissions = .default) async -> Bool {
        await writefile(localPath: localPath, remotePath: remotePath, permissions: permissions) { _, _ in
            true
        }
    }

    // 写入数据到SFTP服务器，不显示进度
    /// 将数据写入指定路径的文件中，不显示写入进度
    /// - Parameters:
    ///   - path: 远程文件路径
    ///   - data: 要写入的数据
    ///   - permissions: 文件权限，默认为默认权限
    /// - Returns: 写入成功返回true，否则返回false
    func writefile(path: String, data: Data, permissions: FilePermissions = .default) async -> Bool {
        await writefile(path: path, data: data, permissions: permissions) { _, _ in
            true
        }
    }
}
