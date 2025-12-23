import Foundation
import Combine
import Darwin

class SystemMonitor: ObservableObject {
    @Published var cpuUsage: Double = 0.0
    @Published var memoryUsage: (used: Double, total: Double) = (0, 0) // GB
    @Published var diskUsage: (used: Double, total: Double) = (0, 0) // GB
    @Published var thermalState: String = "Normal"
    @Published var cpuTemperature: Double = 30.0 // Estimated
    
    private var timer: Timer?
    
    // CPU Calculation State
    private var previousInfo = processor_info_array_t(bitPattern: 0)
    private var previousCount = mach_msg_type_number_t(0)
    
    init() {
        startMonitoring()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    func startMonitoring() {
        // Update every 2 seconds to be efficient
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateStats()
        }
        updateStats() // Initial update
    }
    
    private func updateStats() {
        updateCPU()
        updateMemory()
        updateDisk()
        updateThermalState()
    }
    
    // MARK: - CPU Usage
    private func updateCPU() {
        var count = mach_msg_type_number_t(0)
        var info = processor_info_array_t(bitPattern: 0)
        var infoCount = mach_msg_type_number_t(0)
        
        let result = host_processor_info(mach_host_self(),
                                         PROCESSOR_CPU_LOAD_INFO,
                                         &count,
                                         &info,
                                         &infoCount)
        
        guard result == KERN_SUCCESS, let info = info else { return }
        
        var totalUsage: Double = 0.0
        
        if let prevInfo = previousInfo {
            for i in 0..<Int(count) {
                let index = i * Int(CPU_STATE_MAX)
                
                // Safety check for index bounds
                // info is a pointer, we treat it as array
                let user = Double(info[index + Int(CPU_STATE_USER)] - prevInfo[index + Int(CPU_STATE_USER)])
                let system = Double(info[index + Int(CPU_STATE_SYSTEM)] - prevInfo[index + Int(CPU_STATE_SYSTEM)])
                let nice = Double(info[index + Int(CPU_STATE_NICE)] - prevInfo[index + Int(CPU_STATE_NICE)])
                let idle = Double(info[index + Int(CPU_STATE_IDLE)] - prevInfo[index + Int(CPU_STATE_IDLE)])
                
                let total = user + system + nice + idle
                if total > 0 {
                    totalUsage += (user + system + nice) / total
                }
            }
            
            // Average across cores
            cpuUsage = totalUsage / Double(count)
        }
        
        // Deallocate previous info if it exists
        if let prevInfo = previousInfo {
            let prevSize = Int(previousCount) * MemoryLayout<integer_t>.stride
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: prevInfo), vm_size_t(prevSize))
        }
        
        // Store current info for next tick
        previousInfo = info
        previousCount = infoCount
    }
    
    // MARK: - Memory Usage
    private func updateMemory() {
        var stats = vm_statistics64()
        var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &size)
            }
        }
        
        if result == KERN_SUCCESS {
            let pageSize = Double(vm_kernel_page_size)
            let active = Double(stats.active_count) * pageSize
            let wire = Double(stats.wire_count) * pageSize
            let compressed = Double(stats.compressor_page_count) * pageSize
            
            let used = active + wire + compressed
            let total = Double(ProcessInfo.processInfo.physicalMemory)
            
            memoryUsage = (used / 1_073_741_824, total / 1_073_741_824) // Convert to GB
        }
    }
    
    // MARK: - Disk Usage
    private func updateDisk() {
        do {
            let url = URL(fileURLWithPath: "/")
            let values = try url.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey])
            
            if let total = values.volumeTotalCapacity, let available = values.volumeAvailableCapacity {
                let used = Int64(total) - Int64(available)
                diskUsage = (Double(used) / 1_073_741_824, Double(total) / 1_073_741_824)
            }
        } catch {
            print("Disk usage error: \(error)")
        }
    }
    
    // MARK: - Thermal State & Temperature (Estimated)
    private func updateThermalState() {
        let baseTemp: Double = 35.0
        var thermalOffset: Double = 0.0
        
        // ProcessInfo thermal state is a rough proxy
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: 
            thermalState = "正常"
            thermalOffset = 0.0
        case .fair: 
            thermalState = "温热"
            thermalOffset = 10.0
        case .serious: 
            thermalState = "过热"
            thermalOffset = 25.0
        case .critical: 
            thermalState = "严重过热"
            thermalOffset = 45.0
        @unknown default: 
            thermalState = "未知"
            thermalOffset = 0.0
        }
        
        // Algorithm: Base + (CPU Load * 50) + ThermalOffset
        // REMOVED: Artificial jitter that caused constant UI updates
        let loadFactor = cpuUsage * 50.0
        
        let estimatedTemp = baseTemp + loadFactor + thermalOffset
        
        // Damping: Only update if changed by > 1.0 degree to prevent micro-animations
        if abs(self.cpuTemperature - estimatedTemp) > 1.0 {
             self.cpuTemperature = estimatedTemp
        }
    }
}