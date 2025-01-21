SSH Term APP will adopt a refactored core from version 7.0 onwards.

[https://github.com/sshterm/ssh2](https://github.com/sshterm/ssh2)

# ssh2
Swift + libssh2 + OpenSSL


# Swift Package Manager

The Swift Package Manager is a tool for automating the distribution of Swift code and is integrated into the swift compiler. Once you have your Swift package set up, adding SSH as a dependency is as easy as adding it to the dependencies value of your Package.swift.

```swift
.package(url: "https://github.com/sshterm/ssh2.git", branch: "main")
```

```swift
.product(name: "SSH2", package: "SSH2"),
.product(name: "GeoLite2", package: "SSH2"),
.product(name: "DNS", package: "SSH2")
```

# Demo
```swift
import SSH
import GeoLite2
import Crypto
import DNS

DNS.shared.requireEncrypted(PubDNS.alidns.dohConfiguration)

print(SSH.version,SSH.libssh2_version)

let ssh = SSH(host: "openwrt.local", port: "22", user: "root")
ssh.trace = [.auth]
print(await ssh.checkActive())
print(await ssh.connect())
print(await ssh.handshake())
print(await ssh.authenticate(password: "openwrt"))
print(ssh.clientbanner)
print(ssh.serverbanner)
print(ssh.fingerprint(.md5))

let max = MaxMind.shared
DNS.shared.resolveDomainName("ssh2.app").forEach{print($0,$0.isLanIP,max.lookupIsoCode($0))}

let key = Crypto.shared.generateED25519()
print(key?.pubKeySSH)
print(key?.privKeyPEM)
print(key?.pubKeyPEM)
```

# ssh
libssh2 + OpenSSL + wolfSSL 的swift实现

SSH Term APP [ssh2.app](https://ssh2.app/) 的 SSH2连接核心

全中文注释

# 使用 OpenSSL 版
协议全，推荐

### 不包括libssl，占用空间小
```
pod 'CSSH/OpenSSL', :git => 'https://github.com/sshterm/cssh.git'
pod 'SSH/OpenSSL', :git => 'https://github.com/sshterm/ssh.git'
```

### 使用完整的OpenSSL包括libssl
```
pod 'CSSH/OpenSSLFull', :git => 'https://github.com/sshterm/cssh.git'
pod 'SSH/OpenSSLFull', :git => 'https://github.com/sshterm/ssh.git'
```

# 使用 wolfSSL 版
协议少，不支持ED25519等，适合轻量级应用
```
pod 'CSSH/wolfSSL', :git => 'https://github.com/sshterm/cssh.git'
pod 'SSH/wolfSSL', :git => 'https://github.com/sshterm/ssh.git'
```

# 关于libssh2

https://github.com/libssh2/libssh2

# 关于OpenSSL

https://github.com/openssl/openssl

# 关于wolfSSL

https://github.com/wolfSSL/wolfssl

# 业务说明
    src/ SSH2业务
    src/DNS/ DNS加密业务
    src/Crypto/ 哈希加密业务，包括证书生存等
    src/Machine/ Linux服务器状态查询业务


# Demo

### 加密DNS
```swift
//启动DNS 会自动加密APP的所有DNS请求
DNS.shared.requireEncrypted(.alidns, type: .doh)
```

### SSH2连接
```swift
//创建SSH
 let ssh = SSH(host:  "10.0.0.1", port: 22, user: "root", timeout: 5)
//设置插座
 ssh.sessionDelegate = delegate
 //连接
 await ssh.connect()
 //握手
 await sh.handshake()
 //认证 更多方式 请参考 Auth.swift 的函数注释
 await ssh.authenticate(password: "<PASSWORD>")
```

具体函数用法请参考 代码注释