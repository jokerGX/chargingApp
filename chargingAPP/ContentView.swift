//
//  ContentView.swift
//  chargingAPP
//
//  Created by yikang cheng on 2024/11/4.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var batteryInfo = BatteryInfo()
    
    var body: some View {
        ZStack {
            VStack(spacing: 40) {
                Spacer()
                
                // Circular Battery Indicator
                CircularBatteryView(isCharging: batteryInfo.isCharging, batteryLevel: batteryInfo.batteryLevel)
                    .frame(width: 200, height: 200)
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                
                // Information Cards
                VStack(spacing: 20) {
                    // Charging Status Card
                    InfoCardView(title: "Charging Status",
                                value: chargingStatusText,
                                icon: systemIconName(for: batteryInfo.batteryState),
                                iconColor: chargingStatusColor)
                    
                    // Estimated Time to Full Charge Card
                    InfoCardView(title: "Estimated Time to Full",
                                value: batteryInfo.estimatedTimeToFull,
                                icon: "clock.fill",
                                iconColor: estimatedTimeColor)
                    
                    // Thermal State Indicator Card
                    InfoCardView(title: "Thermal State",
                                value: thermalStateText,
                                icon: "thermometer.sun.fill",
                                iconColor: thermalStateColor)
                }
                .padding(.horizontal, 30)
                
                Spacer()
            }
            .padding()
        }
        .alert(isPresented: $batteryInfo.showCriticalAlert) {
            Alert(title: Text("Critical Thermal State"),
                  message: Text("Your device is overheating. Please take necessary actions."),
                  dismissButton: .default(Text("OK")) {
                      batteryInfo.showCriticalAlert = false
                  })
        }
        .onAppear {
            // Initial update in case notifications were missed
            batteryInfo.handleBatteryStateChange()
            batteryInfo.captureCurrentBatteryLevel()
            batteryInfo.updateThermalState()
        }
    }
    
    // MARK: - Computed Properties for UI Enhancements
    
    private var chargingStatusColor: Color {
        switch batteryInfo.batteryState {
        case .charging:
            return Color.green
        case .full:
            return Color.blue
        case .unplugged:
            return Color.red
        default:
            return Color.gray
        }
    }
    
    private var estimatedTimeColor: Color {
        return Color.blue.opacity(0.8)
    }
    
    private var thermalStateColor: Color {
        switch batteryInfo.thermalState {
        case .nominal:
            return Color.green
        case .fair:
            return Color.yellow
        case .serious:
            return Color.orange
        case .critical:
            return Color.red
        @unknown default:
            return Color.gray
        }
    }
    
    // MARK: - Helper Functions
    
    private func systemIconName(for state: UIDevice.BatteryState) -> String {
        switch state {
        case .charging:
            return "bolt.fill"
        case .full:
            return "checkmark.circle.fill"
        case .unplugged:
            return "battery.100"
        default:
            return "questionmark.circle"
        }
    }
    
    private var chargingStatusText: String {
        switch batteryInfo.batteryState {
        case .unknown:
            return "Unknown"
        case .unplugged:
            return "Not Charging"
        case .charging:
            return "Charging"
        case .full:
            return "Full"
        @unknown default:
            return "Unknown"
        }
    }
    
    private var thermalStateText: String {
        switch batteryInfo.thermalState {
        case .nominal:
            return "Nominal"
        case .fair:
            return "Fair"
        case .serious:
            return "Serious"
        case .critical:
            return "Critical"
        @unknown default:
            return "Unknown"
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
