// DNS.swift
// Copyright (c) 2024 ssh2.app
// Created by admin@ssh2.app 2024/12/1.

import Network

/**
 * DNS 类提供了对 DNS 解析的配置方法，确保域名解析过程中的隐私和安全。
 * - requireEncryptedHTTP: 强制使用加密的 HTTP 提供者进行 DNS 解析。
 * - requireEncryptedTLS: 强制使用加密的 TLS 提供者进行 DNS 解析。
 * - requireEncrypted: 根据提供的类型（.dot 或其他），选择使用加密的 TLS 或 HTTP 提供者进行 DNS 解析。
 */
public class DNS {
    public static let shared: DNS = .init()
}

public extension DNS {
    func requireEncryptedHTTP(_ provider: DNSProvider) {
        NWParameters.PrivacyContext.default.requireEncryptedNameResolution(true, fallbackResolver: provider.http)
    }

    func requireEncryptedTLS(_ provider: DNSProvider) {
        NWParameters.PrivacyContext.default.requireEncryptedNameResolution(true, fallbackResolver: provider.tls)
    }

    func requireEncrypted(_ provider: DNSProvider, type: ProviderType) {
        type == .dot ? requireEncryptedTLS(provider) : requireEncryptedHTTP(provider)
    }
}
