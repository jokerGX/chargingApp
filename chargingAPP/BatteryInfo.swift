//
//  BatteryInfo.swift
//  chargingAPP
//
//  Created by yikang cheng on 2024/11/4.
//

import Foundation
import Combine
import UIKit

class BatteryInfo: ObservableObject {
    // Published properties to update the UI
    @Published var batteryState: UIDevice.BatteryState = .unknown
    @Published var batteryLevel: Float = 0.0
    @Published var isCharging: Bool = false
    @Published var estimatedTimeToFull: String = "Calculating..."
    @Published var thermalState: ProcessInfo.ThermalState = .nominal
    
    // Alert for Critical Thermal State
    @Published var showCriticalAlert: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    private var batteryHistory: [(level: Float, time: Date)] = []
    private let historyLimit = 5 // Number of data points to average
    private var timer: AnyCancellable?
    
    init() {
        // Enable battery monitoring
        UIDevice.current.isBatteryMonitoringEnabled = true
        self.batteryState = UIDevice.current.batteryState
        self.batteryLevel = UIDevice.current.batteryLevel
        self.isCharging = self.batteryState == .charging || self.batteryState == .full
        
        // Observe battery state changes
        NotificationCenter.default.publisher(for: UIDevice.batteryStateDidChangeNotification)
            .sink { [weak self] _ in
                self?.handleBatteryStateChange()
            }
            .store(in: &cancellables)
        
        // Observe battery level changes
        NotificationCenter.default.publisher(for: UIDevice.batteryLevelDidChangeNotification)
            .sink { [weak self] _ in
                self?.updateBatteryLevel()
            }
            .store(in: &cancellables)
        
        // Observe thermal state changes
        NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)
            .sink { [weak self] _ in
                self?.updateThermalState()
            }
            .store(in: &cancellables)
        
        // Start a timer to poll battery level periodically (every 30 seconds)
        startPolling(every: 30)
        
        // Initial data capture
        captureCurrentBatteryLevel()
    }
    
    // MARK: - Handling Battery State Changes
    
    public func handleBatteryStateChange() {
        DispatchQueue.main.async {
            self.batteryState = UIDevice.current.batteryState
            self.isCharging = self.batteryState == .charging || self.batteryState == .full
            
            if self.isCharging {
                // Reset battery history to start fresh
                self.batteryHistory.removeAll()
                self.captureCurrentBatteryLevel()
                
                // Start faster polling to gather data quickly
                self.startPolling(every: 10)
            } else {
                // When not charging, set estimated time accordingly
                if self.batteryState == .full {
                    self.estimatedTimeToFull = "Full Charge"
                } else {
                    self.estimatedTimeToFull = "Not Charging"
                }
                
                // Reset battery history
                self.batteryHistory.removeAll()
                
                // Restore normal polling interval
                self.startPolling(every: 30)
            }
            
            // Handle Full Charge State
            if self.batteryState == .full || self.batteryLevel >= 1.0 {
                self.estimatedTimeToFull = "Full Charge"
                self.isCharging = false
                self.batteryHistory.removeAll() // Reset history
                
                // Stop polling as device is fully charged
                self.timer?.cancel()
                self.timer = nil
            } else if self.isCharging {
                self.estimatedTimeToFull = "Calculating..."
            }
        }
    }
    
    // MARK: - Updating Battery Level
    
    private func updateBatteryLevel() {
        DispatchQueue.main.async {
            let currentLevel = UIDevice.current.batteryLevel
            let currentTime = Date()
            
            // Handle unavailable battery level
            guard currentLevel >= 0 else {
                self.batteryLevel = 0.0
                self.estimatedTimeToFull = "Battery Level Unavailable"
                return
            }
            
            // Update battery level
            self.batteryLevel = currentLevel
            
            // If fully charged
            if self.batteryState == .full || self.batteryLevel >= 1.0 {
                self.estimatedTimeToFull = "Full Charge"
                self.isCharging = false
                self.batteryHistory.removeAll() // Reset history
                
                // Stop polling as device is fully charged
                self.timer?.cancel()
                self.timer = nil
                return
            }
            
            // Add current level and time to history
            self.batteryHistory.append((level: currentLevel, time: currentTime))
            if self.batteryHistory.count > self.historyLimit {
                self.batteryHistory.removeFirst()
            }
            
            self.calculateEstimatedTime()
        }
    }
    
    // MARK: - Capturing Current Battery Level
    
    public func captureCurrentBatteryLevel() {
        let currentLevel = UIDevice.current.batteryLevel
        let currentTime = Date()
        
        // Handle unavailable battery level
        guard currentLevel >= 0 else {
            self.batteryLevel = 0.0
            self.estimatedTimeToFull = "Battery Level Unavailable"
            return
        }
        
        // Update battery level
        self.batteryLevel = currentLevel
        
        // If fully charged
        if self.batteryState == .full || self.batteryLevel >= 1.0 {
            self.estimatedTimeToFull = "Full Charge"
            self.isCharging = false
            self.batteryHistory.removeAll() // Reset history
            
            // Stop polling as device is fully charged
            self.timer?.cancel()
            self.timer = nil
            return
        }
        
        // Add current level and time to history
        self.batteryHistory.append((level: currentLevel, time: currentTime))
        
        // Calculate estimated time immediately
        self.calculateEstimatedTime()
    }
    
    // MARK: - Polling Mechanism
    
    private func pollBatteryLevel() {
        updateBatteryLevel()
    }
    
    private func startPolling(every interval: TimeInterval) {
        // Cancel existing timer if any
        timer?.cancel()
        
        // Start a new timer
        timer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.pollBatteryLevel()
            }
    }
    
    // MARK: - Calculating Estimated Time to Full Charge
    
    private func calculateEstimatedTime() {
        guard isCharging, batteryHistory.count >= 2 else {
            self.estimatedTimeToFull = isCharging ? "Calculating..." : "Not Charging"
            return
        }
        
        // Calculate total charging delta
        let totalDeltaLevel = batteryHistory.last!.level - batteryHistory.first!.level
        let totalDeltaTime = batteryHistory.last!.time.timeIntervalSince(batteryHistory.first!.time)
        
        // Ensure deltaTime is positive and significant
        guard totalDeltaTime > 60, totalDeltaLevel > 0 else { // Minimum 1 minute interval
            self.estimatedTimeToFull = "Calculating..."
            return
        }
        
        let chargingRatePerSecond = totalDeltaLevel / Float(totalDeltaTime) // Level per second
        guard chargingRatePerSecond > 0 else {
            self.estimatedTimeToFull = "Calculating..."
            return
        }
        
        let remainingLevel = 1.0 - batteryHistory.last!.level
        let estimatedSeconds = Double(remainingLevel) / Double(chargingRatePerSecond)
        
        // Update estimated time on the main thread
        DispatchQueue.main.async {
            self.estimatedTimeToFull = self.formatTime(from: estimatedSeconds)
        }
    }
    
    // MARK: - Formatting Time
    
    private func formatTime(from seconds: Double) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .short
        formatter.maximumUnitCount = 2
        return formatter.string(from: seconds) ?? "Calculating..."
    }
    
    // MARK: - Updating Thermal State
    
    public func updateThermalState() {
        DispatchQueue.main.async {
            self.thermalState = ProcessInfo.processInfo.thermalState
            
            // Handle critical thermal state
            if self.thermalState == .critical && !self.showCriticalAlert {
                self.showCriticalAlert = true
            }
        }
    }
//    public func updateThermalState() {
//        DispatchQueue.main.async {
//            // Force critical thermal state for testing
//            self.thermalState = .critical
//            
//            // Handle critical thermal state
//            if self.thermalState == .critical && !self.showCriticalAlert {
//                self.showCriticalAlert = true
//            }
//        }
//    }
    
    deinit {
        // Disable battery monitoring when the object is deallocated
        UIDevice.current.isBatteryMonitoringEnabled = false
        timer?.cancel()
    }
}
