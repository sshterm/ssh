// String+.swift
// Copyright (c) 2024 ssh2.app
// Created by admin@ssh2.app 2024/8/19.

import Darwin
import Foundation

public extension String {
    /// 返回一个指向Data对象字节表示的UnsafeMutablePointer<CChar>
    /// - Returns: 一个指向Data对象字节表示的UnsafeMutablePointer<CChar>
    var pointerCChar: UnsafeMutablePointer<CChar> {
        return withCString { str in
            Darwin.strdup(str)
        }
    }

    // 将当前字符串的长度转换为无符号32位整数类型
    var countUInt32: UInt32 {
        UInt32(count)
    }

    // 将当前字符串的长度转换为有符号32位整数类型
    var countInt32: Int32 {
        Int32(count)
    }
}
