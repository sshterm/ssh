// DNSProvider.swift
// Copyright (c) 2025 ssh2.app
// Created by admin@ssh2.app 2024/12/1.

import Network

public enum DNSProvider: String, CaseIterable {
    case alidns, adguard, google, cloudflare, quad9, s360 = "360", dnspod

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
        case .s360:
            "360"
        case .adguard:
            "AdGuard"
        case .dnspod:
            "DNSPod"
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
        case .s360:
            [
                "101.226.4.6",
                "218.30.118.6",
                "123.125.81.6",
                "140.207.198.6",
            ]
        case .adguard:
            [
                "94.140.14.14",
                "94.140.15.15",
                "2a10:50c0::ad1:ff",
                "2a10:50c0::ad2:ff",
            ]
        case .dnspod:
            [
                "1.12.12.12",
                "120.53.53.53",
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
        case .s360:
            "https://doh.360.cn/dns-query"
        case .adguard:
            "https://dns.adguard.com/dns-query"
        case .dnspod:
            "https://doh.pub/dns-query"
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
        case .s360:
            "dot.360.cn"
        case .adguard:
            "dns.adguard.com"
        case .dnspod:
            "dot.pub"
        }
    }

    var tlsPort: NWEndpoint.Port {
        853
    }

    var httpsPort: NWEndpoint.Port {
        443
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

    var https: NWParameters.PrivacyContext.ResolverConfiguration {
        return .https(serverURL, serverAddresses: getServerAddresses(port: httpsPort))
    }

    var tls: NWParameters.PrivacyContext.ResolverConfiguration? {
        return .tls(getServerHost(port: tlsPort), serverAddresses: getServerAddresses(port: tlsPort))
    }
}

public enum DNSProviderType: String, CaseIterable {
    case doh, dot
}
