// Provider.swift
// Copyright (c) 2024 ssh2.app
// Created by admin@ssh2.app 2024/12/1.

import Network

public enum DNSProvider: String, CaseIterable {
    case alidns, google, cloudflare, quad9

    public var name: String {
        switch self {
        case .cloudflare:
            "Cloudflare"
        case .google:
            "Google"
        case .quad9:
            "Quad9"
        case .alidns:
            "AliDNS"
        }
    }

    public var ips: [String] {
        switch self {
        case .alidns:
            [
                "223.5.5.5",
                "223.6.6.6",
                "2400:3200::1",
                "2400:3200:baba::1",
            ]
        case .google:
            [
                "8.8.8.8",
                "8.8.4.4",
                "2001:4860:4860::8888",
                "2001:4860:4860::8844",
            ]
        case .cloudflare:

            [
                "1.1.1.1",
                "1.0.0.1",
                "2606:4700:4700::1111",
                "2606:4700:4700::1001",
            ]
        case .quad9:

            [
                "9.9.9.9",
                "149.112.112.112",
                "2620:fe::fe",
                "2620:fe::9",
            ]
        }
    }

    public var url: String {
        switch self {
        case .alidns:
            "https://dns.alidns.com/dns-query"
        case .google:
            "https://dns.google/dns-query"
        case .cloudflare:
            "https://cloudflare-dns.com/dns-query"
        case .quad9:
            "https://dns.quad9.net/dns-query"
        }
    }

    public var host: String {
        switch self {
        case .alidns:
            "dns.alidns.com"
        case .google:
            "dns.google"
        case .cloudflare:
            "one.one.one.one"
        case .quad9:
            "dns.quad9.net"
        }
    }

    func getServerAddresses(port: NWEndpoint.Port) -> [NWEndpoint] {
        ips.map { NWEndpoint.hostPort(host: NWEndpoint.Host($0), port: port) }
    }

    var serverURL: URL {
        URL(string: url)!
    }

    func getServerHost(port: NWEndpoint.Port) -> NWEndpoint {
        NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: port)
    }

    var http: NWParameters.PrivacyContext.ResolverConfiguration {
        return .https(serverURL, serverAddresses: getServerAddresses(port: 443))
    }

    var tls: NWParameters.PrivacyContext.ResolverConfiguration? {
        return .tls(getServerHost(port: 853), serverAddresses: getServerAddresses(port: 853))
    }
}

public enum ProviderType: String, CaseIterable {
    case doh, dot
}
