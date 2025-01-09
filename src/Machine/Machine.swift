// Machine.swift
// Copyright (c) 2025 ssh2.app
// Created by admin@ssh2.app 2024/8/23.

import CSSH
import Foundation

public extension SSH {
    /// 检查是否为回显通道
    /// 该函数尝试打开一个SSH通道，并执行'echo '>TEST<'命令来检查通道是否为回显通道。
    /// 如果通道是回显通道，它将返回true，否则返回false。
    func isEcho() async -> Bool {
        guard await openChannel() else {
            return false
        }
        defer {
            self.close(.channel)
        }
        let code = callSSH2 {
            guard let rawChannel = self.rawChannel else {
                return -1
            }
            return libssh2_channel_process_startup(rawChannel, "exec", 4, "echo \">TEST<\"", 13)
        }
        guard code == LIBSSH2_ERROR_NONE else {
            return false
        }
        let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: 6)
        defer {
            buffer.deallocate()
        }
        let rc = callSSH2 {
            guard let rawChannel = self.rawChannel else {
                return -1
            }
            return libssh2_channel_read_ex(rawChannel, 0, buffer, 6)
        }
        guard rc == 6 else {
            return false
        }
        guard let test = ">TEST<".data(using: .utf8) else {
            return false
        }
        guard Data(bytes: buffer, count: 6).range(of: test) != nil else {
            return false
        }
        return true
    }

    /// 获取系统的平均负载信息
    /// - Returns: 返回一个可选的LoadAverage结构体，如果获取失败则返回nil
    func getLoadAverage() async -> LoadAverage? {
        let (text, _) = await exec(command: "cat /proc/loadavg")
        guard let text = text?.trim(),!text.isEmpty else {
            return nil
        }
        let lines = text.components(separatedBy: .whitespaces)
        guard lines.count == 5 else {
            return nil
        }
        let processes = lines[3].components(separatedBy: "/")
        guard processes.count == 2 else {
            return nil
        }
        guard let loadAverage1Min = Double(lines[0]) else {
            return nil
        }
        guard let loadAverage5Min = Double(lines[1]) else {
            return nil
        }
        guard let loadAverage15Min = Double(lines[2]) else {
            return nil
        }
        guard let lastPid = Int(lines[4]) else {
            return nil
        }
        guard let running = Int(processes[0]) else {
            return nil
        }
        guard let total = Int64(processes[1]) else {
            return nil
        }

        return LoadAverage(loadAverage1Min: loadAverage1Min, loadAverage5Min: loadAverage5Min, loadAverage15Min: loadAverage15Min, runningProcesses: running, totalProcesses: total, lastPid: lastPid)
    }

    /// 获取内存信息的异步函数
    /// - Returns: 返回一个可选的MemoryInfo结构体，如果获取失败则返回nil
    func getMemoryInfo() async -> MemoryInfo? {
        let (text, _) = await exec(command: "cat /proc/meminfo")
        guard let text = text?.trim(),!text.isEmpty else {
            return nil
        }

        let lines = text.components(separatedBy: .newlines)
        var memory = MemoryInfo()
        for line in lines {
            let info = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard info.count > 2 else {
                continue
            }

            if info[0].hasPrefix("MemTotal"), let total = Int64(info[1]) {
                memory.total = total * 1024
            } else if info[0].hasPrefix("MemFree"), let free = Int64(info[1]) {
                memory.free = free * 1024
            } else if info[0].hasPrefix("Buffers"), let buffers = Int64(info[1]) {
                memory.buffers = buffers * 1024
            } else if info[0].hasPrefix("Cached"), let cached = Int64(info[1]) {
                memory.cached = cached * 1024
            } else if info[0].hasPrefix("SwapTotal"), let swapTotal = Int64(info[1]) {
                memory.swapTotal = swapTotal * 1024
            } else if info[0].hasPrefix("MemAvailable"), let available = Int64(info[1]) {
                memory.available = available * 1024
            } else if info[0].hasPrefix("Inactive"), let inactive = Int64(info[1]) {
                memory.inactive = inactive * 1024
            } else if info[0].hasPrefix("Active"), let active = Int64(info[1]) {
                memory.active = active * 1024
            } else if info[0].hasPrefix("Shmem"), let shared = Int64(info[1]) {
                memory.shared = shared * 1024
            } else if info[0].hasPrefix("Slab"), let slab = Int64(info[1]) {
                memory.slab = slab * 1024
            }
        }
        memory.used = memory.total - memory.free - memory.buffers - memory.cached - memory.slab
        memory.percent = Double(memory.used) / Double(memory.total)
        return memory
    }

    /// 获取系统状态的异步函数
    /// - Returns: 返回一个可选的SystemStat结构体，如果获取失败则返回nil
    func getSystemStat() async -> SystemStat? {
        let (text, _) = await exec(command: "cat /proc/stat |grep -E \"ctxt|btime|procs_running|procs_blocked\"")
        guard let text = text?.trim(),!text.isEmpty else {
            return nil
        }
        let lines = text.components(separatedBy: .newlines)
        var stat = SystemStat()
        for line in lines {
            let info = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard info.count == 2 else {
                continue
            }
            if info[0].hasPrefix("ctxt"), let ctxt = Int(info[1]) {
                stat.context = ctxt
            } else if info[0].hasPrefix("btime"), let btime = Int(info[1]) {
                stat.bootTime = btime
            } else if info[0].hasPrefix("processes"), let processes = Int(info[1]) {
                stat.processes = processes
            } else if info[0].hasPrefix("procs_running"), let procs_running = Int(info[1]) {
                stat.processesRunning = procs_running
            } else if info[0].hasPrefix("procs_blocked"), let procs_blocked = Int(info[1]) {
                stat.processesBlocked = procs_blocked
            }
        }

        return stat
    }

    /// 获取CPU使用百分比的异步函数。
    /// - Returns: 返回一个可选的CpuPercent对象，如果获取CPU时间失败或CPU时间数量不正确，则返回nil。
    func getCpuPercent() async -> CpuPercent? {
        guard let cputimes = await getCpuTimes() else {
            return nil
        }
        guard cputimes.count == 2 else {
            return nil
        }
        var percent = CpuPercent()
        percent.total = getCpuPercent(cpu_time1: cputimes[0], cpu_time2: cputimes[1])
        percent.user = getCpuUserTime(cpu_time1: cputimes[0], cpu_time2: cputimes[1])
        percent.nice = getCpuNicePercent(cpu_time1: cputimes[0], cpu_time2: cputimes[1])
        percent.system = getCpuSystemPercent(cpu_time1: cputimes[0], cpu_time2: cputimes[1])

        return percent
    }

    /// 计算CPU用户时间百分比
    ///
    /// - Parameters:
    ///   - cpu_time1: 上一个时间点的CPU时间
    ///   - cpu_time2: 当前时间点的CPU时间
    /// - Returns: 用户时间占总时间的百分比
    private func getCpuUserTime(cpu_time1: CpuTimes, cpu_time2: CpuTimes) -> Double {
        let a = (cpu_time2.user) - (cpu_time1.user)
        let b = ((cpu_time2.user + cpu_time2.nice + cpu_time2.system + cpu_time2.idle) - (cpu_time1.user + cpu_time1.nice + cpu_time1.system + cpu_time1.idle))
        return a / b
    }

    /// 计算CPUnice时间百分比
    ///
    /// - Parameters:
    ///   - cpu_time1: 上一个时间点的CPU时间
    ///   - cpu_time2: 当前时间点的CPU时间
    /// - Returns: nice时间占总时间的百分比
    private func getCpuNicePercent(cpu_time1: CpuTimes, cpu_time2: CpuTimes) -> Double {
        let a = (cpu_time2.nice) - (cpu_time1.nice)
        let b = ((cpu_time2.user + cpu_time2.nice + cpu_time2.system + cpu_time2.idle) - (cpu_time1.user + cpu_time1.nice + cpu_time1.system + cpu_time1.idle))
        return a / b
    }

    /// 计算CPU系统时间百分比
    ///
    /// - Parameters:
    ///   - cpu_time1: 上一个时间点的CPU时间
    ///   - cpu_time2: 当前时间点的CPU时间
    /// - Returns: 系统时间占总时间的百分比
    private func getCpuSystemPercent(cpu_time1: CpuTimes, cpu_time2: CpuTimes) -> Double {
        let a = (cpu_time2.system) - (cpu_time1.system)
        let b = ((cpu_time2.user + cpu_time2.nice + cpu_time2.system + cpu_time2.idle) - (cpu_time1.user + cpu_time1.nice + cpu_time1.system + cpu_time1.idle))
        return a / b
    }

    /// 计算CPU总使用百分比（用户、系统、nice）
    ///
    /// - Parameters:
    ///   - cpu_time1: 上一个时间点的CPU时间
    ///   - cpu_time2: 当前时间点的CPU时间
    /// - Returns: CPU总使用百分比
    private func getCpuPercent(cpu_time1: CpuTimes, cpu_time2: CpuTimes) -> Double {
        let a = (cpu_time2.user + cpu_time2.system + cpu_time2.nice) - (cpu_time1.user + cpu_time1.system + cpu_time1.nice)
        let b = ((cpu_time2.user + cpu_time2.nice + cpu_time2.system + cpu_time2.idle) - (cpu_time1.user + cpu_time1.nice + cpu_time1.system + cpu_time1.idle))
        return a / b
    }

    /// 获取CPU时间信息
    /// - Parameter sleep: 在获取两次CPU时间之间等待的秒数，默认为1秒
    /// - Returns: 返回一个包含两个CpuTimes对象的数组，分别代表获取时间点前后的CPU时间信息，如果获取失败则返回nil
    private func getCpuTimes(sleep: Int = 1) async -> [CpuTimes]? {
        let (text, _) = await exec(command: "cpuTime1=$(cat /proc/stat |grep 'cpu ' |awk '{print $2\",\"$3\",\"$4\",\"$5\",\"$6\",\"$7\",\"$8\",\"$9\",\"$10\",\"$11}')\nsleep \(sleep)\ncpuTime2=$(cat /proc/stat |grep 'cpu ' |awk '{print $2\",\"$3\",\"$4\",\"$5\",\"$6\",\"$7\",\"$8\",\"$9\",\"$10\",\"$11}')\necho \"$cpuTime1|$cpuTime2\"")
        guard let text = text?.trim(),!text.isEmpty else {
            return nil
        }

        var cputimes = [CpuTimes(), CpuTimes()]

        let lines = text.components(separatedBy: "|").enumerated()
        for (index, line) in lines {
            let times = line.components(separatedBy: ",").map { Double($0) ?? 0.0 }.enumerated()
            for (i, p) in times {
                switch i {
                case 0: cputimes[index].user = p // 用户态时间
                case 1: cputimes[index].nice = p // 低优先级用户态时间
                case 2: cputimes[index].system = p // 系统态时间
                case 3: cputimes[index].idle = p // 空闲时间
                case 4: cputimes[index].iowait = p // I/O等待时间
                case 5: cputimes[index].irq = p // 中断时间
                case 6: cputimes[index].softirq = p // 软中断时间
                case 7: cputimes[index].steal = p // 虚拟机偷取时间
                case 8: cputimes[index].guest = p // 客户机运行时间
                case 9: cputimes[index].guestNice = p // 客户机低优先级运行时间
                default: break
                }
            }
        }

        return cputimes
    }

    // 获取磁盘I/O信息，通过执行两次系统命令并计算差值来获取磁盘的读写统计信息
    // - 参数:
    //   - sleep: 在两次读取之间等待的秒数，默认为1秒
    // - 返回值:
    //   - DiskIoInfoAll对象，包含磁盘的读写统计信息，如果获取失败则返回nil
    func getDiskIoInfoAll(sleep: Int = 1) async -> DiskIoInfoAll? {
        let (text, _) = await exec(command: "diskRun1=$(cat /proc/diskstats |awk '{print $3\",\"$4\",\"$5\",\"$6\",\"$7\",\"$8\",\"$9\",\"$10\",\"$11\",\"$12\",\"$13\",\"$14}')\nsleep \(sleep)\ndiskRun2=$(cat /proc/diskstats |awk '{print $3\",\"$4\",\"$5\",\"$6\",\"$7\",\"$8\",\"$9\",\"$10\",\"$11\",\"$12\",\"$13\",\"$14}')\necho \"$diskRun1|$diskRun2\"")
        guard let text = text?.trim(),!text.isEmpty else {
            return nil
        }

        let lines = text.components(separatedBy: "|")
        guard lines.count == 2 else {
            return nil
        }

        var disk_io1 = DiskIoInfo()
        var disk_io2 = DiskIoInfo()
        for (i, line) in lines.enumerated() {
            for l in line.components(separatedBy: .newlines) {
                let info = seeDiskInfo(line: l)
                if i == 0 {
                    disk_io1.readCount += info.readCount
                    disk_io1.readMergedCount += info.readMergedCount
                    disk_io1.readBytes += info.readBytes
                    disk_io1.readTime += info.readTime
                    disk_io1.writeCount += info.writeCount
                    disk_io1.writeMergedCount += info.writeMergedCount
                    disk_io1.writeBytes += info.writeBytes
                    disk_io1.writeTime += info.writeTime
                } else if i == 1 {
                    disk_io2.readCount += info.readCount
                    disk_io2.readMergedCount += info.readMergedCount
                    disk_io2.readBytes += info.readBytes
                    disk_io2.readTime += info.readTime
                    disk_io2.writeCount += info.writeCount
                    disk_io2.writeMergedCount += info.writeMergedCount
                    disk_io2.writeBytes += info.writeBytes
                    disk_io2.writeTime += info.writeTime
                }
            }
        }

        var disk_io = DiskIoInfoAll()
        disk_io.totalBytesRead = disk_io2.readBytes
        disk_io.totalBytesWrite = disk_io2.writeBytes
        disk_io.readCount = disk_io2.readCount - disk_io1.readCount
        disk_io.readMergedCount = disk_io2.readMergedCount - disk_io1.readMergedCount
        disk_io.readBytes = disk_io2.readBytes - disk_io1.readBytes
        disk_io.readTime = disk_io2.readTime - disk_io1.readTime
        disk_io.writeCount = disk_io2.writeCount - disk_io1.writeCount
        disk_io.writeMergedCount = disk_io2.writeMergedCount - disk_io1.writeMergedCount
        disk_io.writeBytes = disk_io2.writeBytes - disk_io1.writeBytes
        disk_io.writeTime = disk_io2.writeTime - disk_io1.writeTime
        return disk_io
    }

    /// 解析磁盘IO信息的私有异步函数。
    /// 该函数接收一行文本，包含以逗号分隔的磁盘IO数据，并将其解析为一个DiskIoInfo对象。
    /// 如果解析过程中遇到任何问题，将返回nil。
    ///
    /// - Parameter line: 包含磁盘IO数据的字符串，数据项以逗号分隔。
    /// - Returns: 解析后的DiskIoInfo对象，如果解析失败则返回nil。
    private func seeDiskInfo(line: String) -> DiskIoInfo {
        var io = DiskIoInfo()

        let lines = line.components(separatedBy: ",").enumerated()
        for (i, p) in lines {
            switch i {
            case 0:
                io.name = p
            case 1:
                io.readCount = Int64(p) ?? 0
            case 2:
                io.readMergedCount = Int64(p) ?? 0
            case 3:
                io.readBytes = (Int64(p) ?? 0) * 512
            case 4:
                io.readTime = Int64(p) ?? 0
            case 5:
                io.writeCount = Int64(p) ?? 0
            case 6:
                io.writeMergedCount = Int64(p) ?? 0
            case 7:
                io.writeBytes = (Int64(p) ?? 0) * 512
            case 8:
                io.writeTime = Int64(p) ?? 0
            case 9:
                io.busyTime = Int64(p) ?? 0
            default:
                break
            }
        }
        return io
    }

    // 获取网络IO信息，包括接收和发送的字节数、数据包数以及错误和丢弃的数量
    /// 获取所有网络IO信息，包括两次采样之间的差异
    /// - Parameter sleep: 两次采样之间的等待时间（秒）
    /// - Returns: 网络IO信息结构体，如果获取失败则返回nil
    func getNetworkIoInfoAll(sleep: Int = 1) async -> NetworkIoInfoAll? {
        let (text, _) = await exec(command: "networkRun1=$(cat /proc/net/dev | tail -n +3 |awk '{print $1\",\"$2\",\"$3\",\"$4\",\"$5\",\"$6\",\"$7\",\"$8\",\"$9\",\"$10\",\"$11\",\"$12\",\"$13}')\nsleep \(sleep)\nnetworkRun2=$(cat /proc/net/dev | tail -n +3 |awk '{print $1\",\"$2\",\"$3\",\"$4\",\"$5\",\"$6\",\"$7\",\"$8\",\"$9\",\"$10\",\"$11\",\"$12\",\"$13}')\necho \"$networkRun1|$networkRun2\"")
        guard let text = text?.trim(),!text.isEmpty else {
            return nil
        }

        let lines = text.components(separatedBy: "|")
        guard lines.count == 2 else {
            return nil
        }

        var network_io1 = NetworkIoInfo()
        var network_io2 = NetworkIoInfo()
        for (i, line) in lines.enumerated() {
            for l in line.components(separatedBy: .newlines) {
                let info = seeNetworkInfo(line: l)
                if i == 0 {
                    network_io1.bytesRecv += info.bytesRecv
                    network_io1.packetsRecv += info.packetsRecv
                    network_io1.errin += info.errin
                    network_io1.dropin += info.dropin
                    network_io1.bytesSent += info.bytesSent
                    network_io1.packetsSent += info.packetsSent
                    network_io1.errout += info.errout
                    network_io1.dropout += info.dropout
                } else if i == 1 {
                    network_io2.bytesRecv += info.bytesRecv
                    network_io2.packetsRecv += info.packetsRecv
                    network_io2.errin += info.errin
                    network_io2.dropin += info.dropin
                    network_io2.bytesSent += info.bytesSent
                    network_io2.packetsSent += info.packetsSent
                    network_io2.errout += info.errout
                }
            }
        }

        var network_io = NetworkIoInfoAll()

        network_io.totalBytesSent = network_io2.bytesSent
        network_io.totalBytesRecv = network_io2.bytesRecv
        network_io.bytesRecv = network_io2.bytesRecv - network_io1.bytesRecv
        network_io.packetsRecv = network_io2.packetsRecv - network_io1.packetsRecv
        network_io.errin = network_io2.errin - network_io1.errin
        network_io.dropin = network_io2.dropin - network_io1.dropin
        network_io.bytesSent = network_io2.bytesSent - network_io1.bytesSent
        network_io.packetsSent = network_io2.packetsSent - network_io1.packetsSent
        network_io.errout = network_io2.errout - network_io1.errout
        network_io.dropout = network_io2.dropout - network_io1.dropout
        return network_io
    }

    /// 解析单行网络IO信息
    /// - Parameter line: 单行网络IO信息字符串
    /// - Returns: 解析后的网络IO信息结构体
    private func seeNetworkInfo(line: String) -> NetworkIoInfo {
        var io = NetworkIoInfo()

        let lines = line.components(separatedBy: ",").enumerated()
        for (i, p) in lines {
            switch i {
            case 0:
                io.name = p
            case 1:
                io.bytesRecv = Int64(p) ?? 0
            case 2:
                io.packetsRecv = Int64(p) ?? 0
            case 3:
                io.errin = Int64(p) ?? 0
            case 4:
                io.dropin = Int64(p) ?? 0
            case 9:
                io.bytesSent = Int64(p) ?? 0
            case 10:
                io.packetsSent = Int64(p) ?? 0
            case 11:
                io.errout = Int64(p) ?? 0
            case 12:
                io.dropout = Int64(p) ?? 0
            default:
                break
            }
        }
        return io
    }

    /// 获取系统温度°C信息的异步函数。
    /// 然后将获取到的文本数据转换为Double类型的数组返回。
    /// 如果命令执行失败或转换后的数据为空，则返回nil。
    func getTemp() async -> [Double]? {
        let (text, _) = await exec(command: "cat /sys/class/hwmon/hwmon[0-9]/temp1_input")
        guard let text = text?.trim(),!text.isEmpty else {
            return nil
        }
        let lines = text.components(separatedBy: .newlines).map { Double($0) ?? 0 }.map { $0 / 1000 }
        return lines
    }

    /// 获取温度°C最大值
    /// - Returns: 返回一个可选的Double类型，表示获取到的温度最大值。如果获取失败或没有数据，则返回nil。
    func getTempMax() async -> Double? {
        // 调用getTemp()异步函数获取温度数组，并使用max()方法找出最大值
        return await getTemp()?.max()
    }

    /// 获取当前系统中的线程信息
    /// - Returns: 返回一个包含线程信息的数组，如果获取失败则返回nil
    func getThreads() async -> [Threads]? {
        let (text, _) = await exec(command: "ps -eo pid,tid,%cpu,%mem,user,comm,args --sort=-%cpu | awk 'NR>1 {print $1\",\"$2\",\"$3\",\"$4\",\"$5\",\"$6\",\"$7}'")
        guard let text = text?.trim(),!text.isEmpty else {
            return nil
        }
        let lines = text.components(separatedBy: .newlines)
        var threads: [Threads] = []
        for line in lines {
            let info = line.trim().components(separatedBy: ",")
            guard info.count == 7 else {
                continue
            }
            threads.append(Threads(pid: info[0], tid: info[1], cpu: Double(info[2]) ?? 0, mem: Double(info[3]) ?? 0, user: info[4], comm: info[5], args: info[6]))
        }
        return threads
    }

    /// 获取磁盘使用信息
    /// - Returns: 返回一个DiskInfo对象，包含总的已用空间和可用空间，如果获取失败则返回nil
    func getDiskInfo() async -> DiskInfo? {
        let (text, _) = await exec(command: "df | awk 'NR>1 {print $3\",\"$4}'")
        guard let text = text?.trim(),!text.isEmpty else {
            return nil
        }
        var info = DiskInfo()
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let df = line.trim().components(separatedBy: ",").map { Int64($0) ?? 0 }
            guard df.count == 2 else {
                continue
            }
            info.used += df[0]
            info.avail += df[1]
        }
        return info
    }
}
