// String+.swift
// Copyright (c) 2025 ssh2.app
// Created by admin@ssh2.app 2024/8/19.

import Darwin
import Foundation

extension String {
    /// 返回一个指向Data对象字节表示的UnsafeMutablePointer<CChar>
    /// - Returns: 一个指向Data对象字节表示的UnsafeMutablePointer<CChar>
    var pointerCChar: UnsafeMutablePointer<CChar> {
        withCString { str in
            Darwin.strdup(str)
        }
    }

    // 将当前字符串的长度转换为无符号32位整数类型
    var countUInt32: UInt32 {
        UInt32(utf8.count)
    }

    // 将当前字符串的长度转换为有符号32位整数类型
    var countInt32: Int32 {
        Int32(utf8.count)
    }

    // 冗余，修复错误
    // QQ 飘在深秋 反馈
    /// 返回字符串的UTF-8编码字符数
    var count: Int {
        utf8.count
    }

    func trim() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var isLan: Bool {
        is_lan_ip(self) == 1
    }

    public var isIP: Bool {
        is_ip(self) == 1
    }
}
