// LinuxStats.swift
// Copyright (c) 2024 ssh2.app
// Created by admin@ssh2.app 2024/8/23.

import Foundation

/// 负载平均值结构体，用于存储系统的负载信息和进程信息。
public struct LoadAverage: Identifiable {
    public let id = Date()
    /// 1分钟平均负载
    public var loadAverage1Min: Double = 0

    /// 5分钟平均负载
    public var loadAverage5Min: Double = 0

    /// 15分钟平均负载
    public var loadAverage15Min: Double = 0

    /// 当前运行的进程数
    public var runningProcesses: Int = 0

    /// 系统总进程数
    public var totalProcesses: Int64 = 0

    /// 最后一个进程ID
    public var lastPid: Int = 0
}

public struct MemoryInfo: Identifiable {
    public let id = Date()
    /// 总内存
    public var total: Int64 = 0

    /// 可用内存
    public var available: Int64 = 0

    /// 内存使用百分比
    public var percent: Double = 0

    /// 已使用内存
    public var used: Int64 = 0

    /// 空闲内存
    public var free: Int64 = 0

    /// 活跃内存
    public var active: Int64 = 0

    /// 不活跃内存
    public var inactive: Int64 = 0

    /// 缓冲内存
    public var buffers: Int64 = 0

    /// 缓存内存
    public var cached: Int64 = 0

    /// 共享内存
    public var shared: Int64 = 0

    /// 内核缓冲
    public var slab: Int64 = 0

    /// 总交换空间
    public var swapTotal: Int64 = 0

    /// 空闲交换空间
    public var swapFree: Int64 = 0
}

public struct SystemStat: Identifiable {
    public let id = Date()
    // context 表示上下文信息，默认值为0。
    public var context: Int = 0

    // bootTime 表示系统启动时间，默认值为0。
    public var bootTime: Int = 0

    // processes 表示系统当前进程总数，默认值为0。
    public var processes: Int = 0

    // processesRunning 表示正在运行的进程数，默认值为0。
    public var processesRunning: Int = 0

    // processesBlocked 表示被阻塞的进程数，默认值为0。
    public var processesBlocked: Int = 0
}

public struct CpuTimes {
    /// 用户模式时间
    public var user: Double = 0

    /// 优先级时间
    public var nice: Double = 0

    /// 系统模式时间
    public var system: Double = 0

    /// 空闲时间
    public var idle: Double = 0

    /// 等待I/O操作的时间
    public var iowait: Double = 0

    /// 硬中断时间
    public var irq: Double = 0

    /// 软中断时间
    public var softirq: Double = 0

    /// 被其他进程窃取的时间
    public var steal: Double = 0

    /// 虚拟CPU时间
    public var guest: Double = 0

    /// 虚拟CPU优先级时间
    public var guestNice: Double = 0
}

public struct CpuPercent: Identifiable {
    public let id = Date()
    /// 总CPU使用百分比
    public var total: Double = 0

    /// 用户态CPU使用百分比
    public var user: Double = 0

    /// 优先级为nice的CPU使用百分比
    public var nice: Double = 0

    /// 系统态CPU使用百分比
    public var system: Double = 0
}

// 磁盘信息结构体，用于存储磁盘的统计信息
public struct DiskIoInfo {
    /// 磁盘名称
    public var name: String = ""
    /// 读次数
    public var readCount: Int64 = 0
    /// 写次数
    public var writeCount: Int64 = 0
    /// 读字节数
    public var readBytes: Int64 = 0
    /// 写字节数
    public var writeBytes: Int64 = 0
    /// 读时间
    public var readTime: Int64 = 0
    /// 写时间
    public var writeTime: Int64 = 0
    /// 合并读次数
    public var readMergedCount: Int64 = 0
    /// 合并写次数
    public var writeMergedCount: Int64 = 0
    /// 平均磁盘IO时间
    public var busyTime: Int64 = 0
}

public struct DiskIoInfoAll: Identifiable {
    public let id = Date()
    /// 读取的总字节数
    public var totalBytesRead: Int64 = 0
    /// 写入的总字节数
    public var totalBytesWrite: Int64 = 0
    /// 读操作的总次数
    public var readCount: Int64 = 0
    /// 写操作的总次数
    public var writeCount: Int64 = 0
    /// 读取的总字节数
    public var readBytes: Int64 = 0
    /// 写入的总字节数
    public var writeBytes: Int64 = 0
    /// 读取操作的总时间
    public var readTime: Int64 = 0
    /// 写入操作的总时间
    public var writeTime: Int64 = 0
    /// 合并读取操作的总次数
    public var readMergedCount: Int64 = 0
    /// 合并写入操作的总次数
    public var writeMergedCount: Int64 = 0
}

public struct NetworkIoInfo {
    /// 网卡名称
    public var name: String = ""
    /// 发送字节数
    public var bytesSent: Int64 = 0
    /// 接收字节数
    public var bytesRecv: Int64 = 0
    /// 发送包数
    public var packetsSent: Int64 = 0
    /// 接收包数
    public var packetsRecv: Int64 = 0
    /// 接收错误包数
    public var errin: Int64 = 0
    /// 发送错误包数
    public var errout: Int64 = 0
    /// 接收丢弃包数
    public var dropin: Int64 = 0
    /// 发送丢弃包数
    public var dropout: Int64 = 0
}

public struct NetworkIoInfoAll: Identifiable {
    public let id = Date()
    /// 发送的总字节数
    public var totalBytesSent: Int64 = 0
    /// 接收的总字节数
    public var totalBytesRecv: Int64 = 0
    /// 发送的字节数
    public var bytesSent: Int64 = 0
    /// 接收的字节数
    public var bytesRecv: Int64 = 0
    /// 发送的数据包总数
    public var packetsSent: Int64 = 0
    /// 接收的数据包总数
    public var packetsRecv: Int64 = 0
    /// 接收时错误的包数
    public var errin: Int64 = 0
    /// 发送时错误的包数
    public var errout: Int64 = 0
    /// 接收时丢弃的包数
    public var dropin: Int64 = 0
    /// 发送时丢弃的包数
    public var dropout: Int64 = 0
}

public struct Threads: Identifiable {
    // 线程的唯一标识符，使用pid作为id
    public var id: String {
        pid
    }

    // 线程的进程ID
    public let pid: String
    // 线程的ID
    public let tid: String
    // 线程占用的CPU百分比
    public let cpu: Double
    // 线程占用的内存百分比
    public let mem: Double
    // 线程的用户
    public let user: String
    // 线程的命令名称
    public let comm: String
    // 线程的命令行参数
    public let args: String
}

public struct DiskInfo: Identifiable {
    // 磁盘信息的唯一标识符，使用UUID生成
    public let id = UUID()
    // 磁盘已使用的空间大小
    public var used: Int64 = 0
    // 磁盘可用的空间大小
    public var avail: Int64 = 0
}
