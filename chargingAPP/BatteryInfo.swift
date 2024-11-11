import Foundation
import Combine
import UIKit
import FirebaseFirestore

class BatteryInfo: ObservableObject {
    // Published properties to update the UI
    @Published var batteryLevel: Float = 0.0
    @Published var isCharging: Bool = false
    @Published var estimatedTimeToFull: String = "Calculating..."
    @Published var thermalState: ProcessInfo.ThermalState = .nominal
    
    // Alert for Critical Thermal State
    @Published var showCriticalAlert: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    private var batteryHistory: [(level: Float, time: Date)] = []
    private let historyLimit = 5 // Number of data points to average
    
    // Firestore reference
    private let db = Firestore.firestore()
    private let deviceID: String
    private let deviceName: String
    
    init() {
        // Initialize device ID and name
        self.deviceID = UIDevice.current.uniqueID
        self.deviceName = UIDevice.current.name
        
        // Enable battery monitoring
        UIDevice.current.isBatteryMonitoringEnabled = true
        self.batteryLevel = UIDevice.current.batteryLevel
        self.isCharging = UIDevice.current.batteryState == .charging || UIDevice.current.batteryState == .full
        
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
        
        // Observe changes to published properties and update Firestore accordingly
        Publishers.CombineLatest4($batteryLevel, $isCharging, $estimatedTimeToFull, $thermalState)
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] level, charging, time, thermal in
                self?.sendBatteryDataToFirestore()
            }
            .store(in: &cancellables)
        
        // Initial data capture
        captureCurrentBatteryLevel()
        sendBatteryDataToFirestore()
    }
    
    // MARK: - Handling Battery State Changes
    
    public func handleBatteryStateChange() {
        DispatchQueue.main.async {
            self.isCharging = UIDevice.current.batteryState == .charging || UIDevice.current.batteryState == .full
            
            if self.isCharging {
                // Reset battery history to start fresh
                self.batteryHistory.removeAll()
                self.captureCurrentBatteryLevel()
            } else {
                // When not charging, set estimated time accordingly
                if UIDevice.current.batteryState == .full {
                    self.estimatedTimeToFull = "Full Charge"
                } else {
                    self.estimatedTimeToFull = "Not Charging"
                }
                
                // Reset battery history
                self.batteryHistory.removeAll()
            }
            
            // Handle Full Charge State
            if UIDevice.current.batteryState == .full || self.batteryLevel >= 1.0 {
                self.estimatedTimeToFull = "Full Charge"
                self.isCharging = false
                self.batteryHistory.removeAll() // Reset history
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
            if UIDevice.current.batteryState == .full || self.batteryLevel >= 1.0 {
                self.estimatedTimeToFull = "Full Charge"
                self.isCharging = false
                self.batteryHistory.removeAll() // Reset history
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
        if UIDevice.current.batteryState == .full || self.batteryLevel >= 1.0 {
            self.estimatedTimeToFull = "Full Charge"
            self.isCharging = false
            self.batteryHistory.removeAll() // Reset history
            return
        }
        
        // Add current level and time to history
        self.batteryHistory.append((level: currentLevel, time: currentTime))
        
        // Calculate estimated time immediately
        self.calculateEstimatedTime()
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
    
    // MARK: - Sending Data to Firestore
    
    private func sendBatteryDataToFirestore() {
        // Reference to the "batteryData" collection with deviceID as document ID
        let batteryDocument = db.collection("batteryData").document(deviceID)
        
        // Prepare data to send
        let data: [String: Any] = [
            "deviceID": deviceID,
            "deviceName": deviceName,
            "timestamp": Timestamp(date: Date()),
            "batteryLevel": batteryLevel,
            "isCharging": isCharging,
            "estimatedTimeToFull": estimatedTimeToFull,
            "thermalState": thermalStateString()
        ]
        
        // Set data to Firestore (merge to update existing fields)
        batteryDocument.setData(data, merge: true) { error in
            if let error = error {
                print("Error sending battery data to Firestore: \(error.localizedDescription)")
            } else {
                print("Battery data successfully sent to Firestore.")
            }
        }
    }
    
    // Helper methods to convert enums to strings
    private func thermalStateString() -> String {
        switch thermalState {
        case .nominal:
            return "nominal"
        case .fair:
            return "fair"
        case .serious:
            return "serious"
        case .critical:
            return "critical"
        @unknown default:
            return "unknown"
        }
    }
    
    deinit {
        // Disable battery monitoring when the object is deallocated
        UIDevice.current.isBatteryMonitoringEnabled = false
    }
}
