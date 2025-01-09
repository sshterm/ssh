// CChar+.swift
// Copyright (c) 2025 ssh2.app
// Created by admin@ssh2.app 2024/8/18.

import Foundation

// 为UnsafeMutablePointer<CChar>类型添加一个计算属性string
public extension UnsafeMutablePointer<CChar> {
    // 将C语言风格的字符串转换为Swift的String类型
    var string: String {
        String(cString: self)
    }
}
