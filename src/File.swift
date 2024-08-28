// File.swift
// Copyright (c) 2024 ssh2.app
// Created by admin@ssh2.app 2024/8/17.

import CSSH
import Foundation

public struct FileStat {
    // 文件类型
    public let fileType: FileType

    // 文件大小
    public let size: UInt64

    // 用户ID
    public let userId: UInt

    // 组ID
    public let groupId: UInt

    // 文件权限
    public let permissions: FilePermissions

    // 最后访问时间
    public let lastAccessed: Date

    // 最后修改时间
    public let lastModified: Date

    /**
     初始化FileStat结构体
     - Parameters:
        - attributes: LIBSSH2_SFTP_ATTRIBUTES类型的属性，包含文件的各种信息
     - Returns: 如果能成功解析attributes，则返回FileStat实例，否则返回nil
     */
    init(attributes: LIBSSH2_SFTP_ATTRIBUTES) {
        fileType = FileType(rawValue: Int32(attributes.permissions))
        // 直接赋值其他属性
        size = attributes.filesize
        userId = attributes.uid
        groupId = attributes.gid
        permissions = FilePermissions(rawValue: Int32(attributes.permissions))
        lastAccessed = Date(timeIntervalSince1970: Double(attributes.atime))
        lastModified = Date(timeIntervalSince1970: Double(attributes.mtime))
    }
}

public struct FileAttributes: Identifiable {
    public let id = UUID()
    // 文件名
    public let name: String
    // 文件的长名称，可能包含用户和组信息
    public let longname: String

    // 文件类型
    public let fileType: FileType

    // 文件大小
    public let size: Int64

    // 文件所有者
    public let user: String

    // 文件所属组
    public let group: String

    // 用户ID
    public let userId: UInt

    // 组ID
    public let groupId: UInt

    // 文件权限
    public let permissions: FilePermissions

    // 最后访问时间
    public let lastAccessed: Date

    // 最后修改时间
    public let lastModified: Date

    /**
     使用LIBSSH2_SFTP_ATTRIBUTES结构体初始化FileAttributes实例

     - Parameters:
        - attributes: LIBSSH2_SFTP_ATTRIBUTES结构体，包含文件属性信息

     - Returns: 如果fileType能够从attributes.permissions正确解析，则返回FileAttributes实例，否则返回nil
     */
    init(attributes: LIBSSH2_SFTP_ATTRIBUTES) {
        fileType = FileType(rawValue: Int32(attributes.permissions))
        name = ""
        longname = ""
        size = Int64(attributes.filesize)
        userId = attributes.uid
        groupId = attributes.gid
        permissions = FilePermissions(rawValue: Int32(attributes.permissions))
        lastAccessed = Date(timeIntervalSince1970: Double(attributes.atime))
        lastModified = Date(timeIntervalSince1970: Double(attributes.mtime))
        user = ""
        group = ""
    }

    /**
     使用文件名、长名称和LIBSSH2_SFTP_ATTRIBUTES结构体初始化FileAttributes实例

     - Parameters:
        - name: 文件名
        - longname: 文件的长名称，可能包含用户和组信息
        - attributes: LIBSSH2_SFTP_ATTRIBUTES结构体，包含文件属性信息

     - Returns: 如果fileType能够从attributes.permissions正确解析，则返回FileAttributes实例，否则返回nil
     */
    init(name: String, longname: String, attributes: LIBSSH2_SFTP_ATTRIBUTES) {
        fileType = FileType(rawValue: Int32(attributes.permissions))
        self.name = name
        self.longname = longname
        size = Int64(attributes.filesize)
        userId = attributes.uid
        groupId = attributes.gid
        permissions = FilePermissions(rawValue: Int32(attributes.permissions))
        lastAccessed = Date(timeIntervalSince1970: Double(attributes.atime))
        lastModified = Date(timeIntervalSince1970: Double(attributes.mtime))
        user = sftpParseLongname(longname, .owner) ?? ""
        group = sftpParseLongname(longname, .group) ?? ""
    }
}

enum SFTPField: Int {
    case perm = 0 // 权限
    case fixme // 待修复
    case owner // 所有者
    case group // 组
    case size // 大小
    case moon // 月份
    case day // 日期
    case time // 时间
}

/// 解析长文件名中的特定字段
///
/// - Parameters:
///   - longname: 包含多个字段的长文件名字符串
///   - field: 需要解析的SFTP字段枚举值
/// - Returns: 如果长文件名有效且请求的字段存在，则返回该字段的值；否则返回nil
func sftpParseLongname(_ longname: String, _ field: SFTPField) -> String? {
    // 使用空格分割长文件名字符串
    let components = longname.split(separator: " ")
    // 检查分割后的组件数量是否大于8，以及请求的字段索引是否在有效范围内
    guard components.count > 8, field.rawValue < components.count else { return nil }
    // 返回请求字段的值
    return String(components[field.rawValue])
}

// Permissions 结构体定义了一个权限集合，它使用 OptionSet 协议来实现位掩码操作。
public struct Permissions: OptionSet {
    // rawValue 属性用于存储权限集合的原始值，该值是一个无符号整数。
    public let rawValue: UInt

    // init(rawValue:) 是 Permissions 结构体的初始化器，用于根据给定的原始值创建权限实例。
    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    // read 是一个静态属性，表示读权限。它的 rawValue 设置为 1 左移 1 位，即二进制的 0010。
    public static let read = Permissions(rawValue: 1 << 1)

    // write 是一个静态属性，表示写权限。它的 rawValue 设置为 1 左移 2 位，即二进制的 0100。
    public static let write = Permissions(rawValue: 1 << 2)

    // execute 是一个静态属性，表示执行权限。它的 rawValue 设置为 1 左移 3 位，即二进制的 1000。
    public static let execute = Permissions(rawValue: 1 << 3)
}

public struct FilePermissions: RawRepresentable {
    // 文件所有者的权限
    public var owner: Permissions

    // 文件所属组的权限
    public var group: Permissions

    // 其他用户的权限
    public var others: Permissions

    /**
     初始化文件对象

     - Parameters:
        - owner: 文件所有者的权限对象
        - group: 文件所属组的权限对象
        - others: 其他用户的权限对象
     */
    public init(owner: Permissions, group: Permissions, others: Permissions) {
        self.owner = owner
        self.group = group
        self.others = others
    }

    // 初始化方法，根据传入的原始整数值设置文件权限
    public init(rawValue: Int32) {
        // 初始化所有者、组和其他用户的权限集合
        var owner: Permissions = []
        var group: Permissions = []
        var others: Permissions = []

        // 检查并设置所有者的读权限
        if rawValue & LIBSSH2_SFTP_S_IRUSR == LIBSSH2_SFTP_S_IRUSR { owner.insert(.read) }
        // 检查并设置所有者的写权限
        if rawValue & LIBSSH2_SFTP_S_IWUSR == LIBSSH2_SFTP_S_IWUSR { owner.insert(.write) }
        // 检查并设置所有者的执行权限
        if rawValue & LIBSSH2_SFTP_S_IXUSR == LIBSSH2_SFTP_S_IXUSR { owner.insert(.execute) }
        // 检查并设置组的读权限
        if rawValue & LIBSSH2_SFTP_S_IRGRP == LIBSSH2_SFTP_S_IRGRP { group.insert(.read) }
        // 检查并设置组的写权限
        if rawValue & LIBSSH2_SFTP_S_IWGRP == LIBSSH2_SFTP_S_IWGRP { group.insert(.write) }
        // 检查并设置组的执行权限
        if rawValue & LIBSSH2_SFTP_S_IXGRP == LIBSSH2_SFTP_S_IXGRP { group.insert(.execute) }
        // 检查并设置其他用户的读权限
        if rawValue & LIBSSH2_SFTP_S_IROTH == LIBSSH2_SFTP_S_IROTH { others.insert(.read) }
        // 检查并设置其他用户的写权限
        if rawValue & LIBSSH2_SFTP_S_IWOTH == LIBSSH2_SFTP_S_IWOTH { others.insert(.write) }
        // 检查并设置其他用户的执行权限
        if rawValue & LIBSSH2_SFTP_S_IXOTH == LIBSSH2_SFTP_S_IXOTH { others.insert(.execute) }

        // 使用设置好的权限集合初始化当前对象
        self.init(owner: owner, group: group, others: others)
    }

    public var rawUInt: UInt {
        UInt(rawValue)
    }

    public var rawInt: Int {
        Int(rawValue)
    }

    // 计算并返回SFTP文件权限的原始值
    public var rawValue: Int32 {
        var flag: Int32 = 0 // 初始化权限标志为0

        // 检查所有者是否有读权限，并更新权限标志
        if owner.contains(.read) { flag |= LIBSSH2_SFTP_S_IRUSR }
        // 检查所有者是否有写权限，并更新权限标志
        if owner.contains(.write) { flag |= LIBSSH2_SFTP_S_IWUSR }
        // 检查所有者是否有执行权限，并更新权限标志
        if owner.contains(.execute) { flag |= LIBSSH2_SFTP_S_IXUSR }

        // 检查组是否有读权限，并更新权限标志
        if group.contains(.read) { flag |= LIBSSH2_SFTP_S_IRGRP }
        // 检查组是否有写权限，并更新权限标志
        if group.contains(.write) { flag |= LIBSSH2_SFTP_S_IWGRP }
        // 检查组是否有执行权限，并更新权限标志
        if group.contains(.execute) { flag |= LIBSSH2_SFTP_S_IXGRP }

        // 检查其他用户是否有读权限，并更新权限标志
        if others.contains(.read) { flag |= LIBSSH2_SFTP_S_IROTH }
        // 检查其他用户是否有写权限，并更新权限标志
        if others.contains(.write) { flag |= LIBSSH2_SFTP_S_IWOTH }
        // 检查其他用户是否有执行权限，并更新权限标志
        if others.contains(.execute) { flag |= LIBSSH2_SFTP_S_IXOTH }

        return flag // 返回计算出的权限原始值
    }

    // mode属性用于获取文件权限的八进制表示形式。
    // 它通过将rawValue与0o777进行按位与操作，然后使用String的format方法将其转换为三位八进制字符串。
    public var mode: String {
        String(format: "%03o", rawValue & 0o777)
    }

    /// FilePermissions结构体的默认实例，表示文件权限。
    /// - owner: 文件所有者的权限，默认为可读可写。
    /// - group: 文件所属组的权限，默认为可读。
    /// - others: 其他用户的权限，默认为可读。
    public static let `default` = FilePermissions(owner: [.read, .write], group: [.read], others: [.read])
}

public struct Statvfs {
    // 文件系统块大小
    public let bsize: UInt64
    // 系统分配的块大小
    public let frsize: UInt64
    // 文件系统数据块总数
    public let blocks: UInt64
    // 可用数据块总数
    public let bfree: UInt64
    // 非超级用户可用的数据块总数
    public let bavail: UInt64
    // 文件结点总数
    public let files: UInt64
    // 可用文件结点总数
    public let ffree: UInt64
    // 非超级用户可用的文件结点总数
    public let favail: UInt64
    // 文件系统ID
    public let fsid: UInt64
    // 文件系统标志
    public let flag: UInt64
    // 文件名的最大长度
    public let namemax: UInt64

    /**
     初始化Statvfs结构体实例
     - Parameter statvfs: LIBSSH2_SFTP_STATVFS类型的结构体，包含文件系统的统计信息
     */
    init(statvfs: LIBSSH2_SFTP_STATVFS) {
        bsize = statvfs.f_bsize
        frsize = statvfs.f_frsize
        blocks = statvfs.f_blocks
        bfree = statvfs.f_bfree
        bavail = statvfs.f_bavail
        files = statvfs.f_files
        ffree = statvfs.f_ffree
        favail = statvfs.f_favail
        fsid = statvfs.f_fsid
        flag = statvfs.f_flag
        namemax = statvfs.f_namemax
    }
}
