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
char *get_ip_addresses(const char *domain);
#endif /* dns_h */
