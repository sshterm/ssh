// dns.c
// Copyright (c) 2024 ssh2.app
// Created by admin@ssh2.app 2024/12/1.

#include "dns.h"
char *get_ip_addresses(const char *domain)
{
    struct addrinfo hints, *res, *p;
    char ip_str[INET6_ADDRSTRLEN];
    char *ip_addresses = malloc(1024); // 分配足够的空间以存储 IP 地址，建议大小根据需要调整
    if (!ip_addresses)
    {
        return NULL; // 内存分配失败
    }
    ip_addresses[0] = '\0'; // 初始化为空字符串

    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;     // AF_UNSPEC to allow both IPv4 and IPv6
    hints.ai_socktype = SOCK_STREAM; // TCP stream sockets

    // 获取地址信息
    int status = getaddrinfo(domain, NULL, &hints, &res);
    if (status != 0)
    {
        free(ip_addresses);
        return NULL; // 返回 NULL 表示失败
    }

    // 遍历所有结果并将 IP 地址添加到字符串中
    for (p = res; p != NULL; p = p->ai_next)
    {
        void *addr_ptr;
        if (p->ai_family == AF_INET)
        { // IPv4
            struct sockaddr_in *ipv4 = (struct sockaddr_in *)p->ai_addr;
            addr_ptr = &(ipv4->sin_addr);
        }
        else
        { // IPv6
            struct sockaddr_in6 *ipv6 = (struct sockaddr_in6 *)p->ai_addr;
            addr_ptr = &(ipv6->sin6_addr);
        }

        // 将地址转换为字符串
        inet_ntop(p->ai_family, addr_ptr, ip_str, sizeof(ip_str));

        // 将 IP 地址添加到返回字符串中
        strcat(ip_addresses, ip_str);
        strcat(ip_addresses, "\n"); // 添加换行符，格式化输出
    }

    freeaddrinfo(res);   // 释放链表
    return ip_addresses; // 返回包含 IP 地址的字符串
}

int is_ipv4(const char *ip_str)
{
    struct in_addr addr;
    return inet_pton(AF_INET, ip_str, &addr);
}

int is_ipv6(const char *ip_str)
{
    struct in6_addr addr;
    return inet_pton(AF_INET6, ip_str, &addr);
}

int is_ipv6_lan_ip(const char *ip_str)
{
    struct in6_addr addr;
    if (!inet_pton(AF_INET6, ip_str, &addr))
    {
        return 0;
    }
    unsigned char *bytes = addr.s6_addr;
    if (bytes[0] == 0xfc && (bytes[1] & 0x80) == 0x80)
    {
        return 1;
    }
    return 0;
}

int is_ipv4_lan_ip(const char *ip_str)
{
    struct in_addr addr;
    if (!inet_pton(AF_INET, ip_str, &addr))
    {
        return 0;
    }
    uint32_t ip = ntohl(addr.s_addr);
    if ((ip >= 0x0A000000 && ip <= 0x0AFFFFFF) || // 10.0.0.0/8
        (ip >= 0xAC100000 && ip <= 0xAC1F255F) || // 172.16.0.0/12 的前半部分
        (ip >= 0xAC100000 && ip <= 0xAC3FFFFF) || // 172.16.0.0/12 的后半部分
        (ip >= 0xC0A80000 && ip <= 0xC0A8FFFF))
    {
        // 192.168.0.0/16
        return 1;
    }
    return 0;
}

int is_lan_ip(const char *ip_str)
{
    return is_ipv6_lan_ip(ip_str) || is_ipv4_lan_ip(ip_str);
}

int is_ip(const char *ip_str)
{
    return is_ipv4(ip_str) || is_ipv6(ip_str);
}
