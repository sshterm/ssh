// Data+.swift
// Copyright (c) 2025 ssh2.app
// Created by admin@ssh2.app 2024/8/18.

import Foundation

public extension Data {
    /// 返回一个指向Data对象字节表示的UnsafeMutablePointer<CChar>
    /// - Returns: 一个指向Data对象字节表示的UnsafeMutablePointer<CChar>
    var pointerCChar: UnsafeMutablePointer<CChar> {
        let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: count)
        withUnsafeBytes { bytes in
            if let from = bytes.bindMemory(to: CChar.self).baseAddress {
                buffer.update(from: from, count: count)
            }
        }
        return buffer
    }

    // 将字节数组转换为十六进制字符串数组
    var hex: [String] {
        map { String(format: "%02hhX", $0) } // 使用格式化字符串将每个字节转换为两位十六进制表示
    }

    // 将十六进制字符串数组连接成一个完整的十六进制字符串
    var hexString: String {
        hex.joined() // 使用joined方法将数组中的所有元素连接成一个字符串
    }

    // 将十六进制字符串数组以冒号分隔的形式连接成一个完整的十六进制字符串，用于表示指纹
    var fingerprint: String {
        hex.joined(separator: ":") // 使用joined方法并指定分隔符为冒号来连接数组中的所有元素
    }

    // 尝试将Data对象解码为UTF-8字符串，如果失败则返回空字符串
    var string: String {
        String(data: self, encoding: .utf8) ?? ""
    }

    func trim() -> String {
        string.trim()
    }

    // 返回Data对象的字节长度作为UInt32类型的值
    var countUInt32: UInt32 {
        UInt32(count)
    }

    // 返回Data对象的字节长度作为Int32类型的值
    var countInt32: Int32 {
        Int32(count)
    }

    // 将count属性的值转换为Int32类型
    var countInt64: Int64 {
        Int64(count)
    }
    
    var bool: Bool{
        let bool: UInt8 = load()
        return bool == 1
    }

    func load<T>() -> T where T: FixedWidthInteger {
        return withUnsafeBytes { ptr in
            ptr.load(fromByteOffset: 0, as: T.self)
        }
    }

    static func from<T>(_ v: T) -> Data where T: FixedWidthInteger {
        var value = v
        return Data(bytes: &value, count: MemoryLayout<T>.size)
    }

    static func from(_ value: String) -> Data {
        return Data(value.utf8)
    }

    static func from(_ value: Bool) -> Data {
        let bool: UInt8 = value ? 1 : 0
        return .from(bool)
    }
}
