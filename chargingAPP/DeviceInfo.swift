//
//  DeviceInfo.swift
//  chargingAPP
//
//  Created by yikang cheng on 2024/11/10.
//


import Foundation

struct DeviceInfo: Codable {
    enum BatteryState: String, Codable {
        case unknown
        case unplugged
        case charging
        case full
    }
    
    enum ThermalState: String, Codable {
        case nominal
        case fair
        case serious
        case critical
    }
    
    var batteryState: BatteryState
    var batteryLevel: Float
    var isCharging: Bool
    var estimatedTimeToFull: String
    var thermalState: ThermalState
    var timestamp: Date
}
