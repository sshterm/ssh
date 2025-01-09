// DNS.swift
// Copyright (c) 2025 ssh2.app
// Created by admin@ssh2.app 2024/12/1.

import Foundation
import Network

/**
 * DNS 类提供了对 DNS 解析的配置方法，确保域名解析过程中的隐私和安全。
 */
public class DNS {
    public static let shared: DNS = .init()
}

public extension DNS {
    /**
     * 确保DNS解析使用加密的DOH连接。
     * 该方法要求隐私上下文默认启用加密的名称解析，并在需要时回退到提供的TLS解析器。
     *
     * @param provider DNSProvider类型，提供DOH解析器。
     */
    func requireEncryptedHTTPS(_ provider: DNSProvider) {
        NWParameters.PrivacyContext.default.requireEncryptedNameResolution(true, fallbackResolver: provider.https)
    }

    /**
     * 确保DNS解析使用加密的DOT连接。
     * 该方法要求隐私上下文默认启用加密的名称解析，并在需要时回退到提供的DOT解析器。
     *
     * @param provider DNSProvider类型，提供DOT解析器。
     */
    func requireEncryptedTLS(_ provider: DNSProvider) {
        NWParameters.PrivacyContext.default.requireEncryptedNameResolution(true, fallbackResolver: provider.tls)
    }

    /**
     * 根据提供商类型要求加密连接。
     * 如果提供商类型是 `.dot`，则要求使用加密的 TLS 连接；
     * 否则，要求使用加密的 HTTPS 连接。
     *
     * @param provider DNS 提供商实例
     * @param type 提供商类型
     */
    func requireEncrypted(_ provider: DNSProvider, type: DNSProviderType) {
        type == .dot ? requireEncryptedTLS(provider) : requireEncryptedHTTPS(provider)
    }

    /**
     * 查询给定主机名的 IP 地址列表。
     * 该函数尝试获取指定主机名的所有 IP 地址，并将其转换为字符串数组返回。
     * 如果无法获取 IP 地址，则返回空数组。
     *
     * @param hostname 要查询的主机名。
     * @return 包含 IP 地址的字符串数组，如果无法获取则返回空数组。
     */
    func queryIP(_ hostname: String) -> [String] {
        if is_ip(hostname) == 1 {
            return [hostname]
        }
        guard let ips = get_ip_addresses(hostname) else {
            return []
        }
        return String(cString: ips).trim().components(separatedBy: .newlines)
    }
}
