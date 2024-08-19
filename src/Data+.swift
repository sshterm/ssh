// Data+.swift
// Copyright (c) 2024 ssh2.app
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

    var hexString: String {
        map { String(format: "%02hhX", $0) }.joined()
    }

    var string: String {
        String(data: self, encoding: .utf8) ?? ""
    }

    var countUInt32: UInt32 {
        UInt32(count)
    }

    var countInt32: Int32 {
        Int32(count)
    }
}
