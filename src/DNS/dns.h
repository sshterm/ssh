// dns.h
// Copyright (c) 2024 ssh2.app
// Created by admin@ssh2.app 2024/12/1.

#ifndef dns_h
#define dns_h
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>
#include <arpa/inet.h>

// 获取域名IP
char *get_ip_addresses(const char *domain);

// 判断给定的字符串是否是有效的IPv4地址
int is_ipv4(const char *ip_str);

// 判断给定的字符串是否是有效的IPv6地址
int is_ipv6(const char *ip_str);

// 判断给定的字符串是否是有效的IPv6局域网地址
int is_ipv6_lan_ip(const char *ip_str);

// 判断给定的字符串是否是有效的IPv4局域网地址
int is_ipv4_lan_ip(const char *ip_str);

// 判断给定的字符串是否是局域网IP地址（包括IPv4和IPv6）
int is_lan_ip(const char *ip_str);

// 判断给定的字符串是否是IP地址（包括IPv4和IPv6）
int is_ip(const char *ip_str);
#endif /* dns_h */
