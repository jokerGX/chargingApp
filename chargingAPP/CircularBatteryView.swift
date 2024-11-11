//
//  CircularBatteryView.swift
//  chargingAPP
//
//  Created by yikang cheng on 2024/11/4.
//

import SwiftUI

struct CircularBatteryView: View {
    var isCharging: Bool
    var batteryLevel: Float
    
    var body: some View {
        ZStack {
            // Background Circle
            Circle()
                .stroke(lineWidth: 20)
                .opacity(0.2)
                .foregroundColor(Color.white)
            
            // Progress Circle
            Circle()
                .trim(from: 0.0, to: CGFloat(min(batteryLevel, 1.0)))
                .stroke(
                    AngularGradient(gradient: Gradient(colors: [Color.green, Color.blue]),
                                    center: .center),
                    style: StrokeStyle(lineWidth: 20, lineCap: .round, lineJoin: .round)
                )
                .rotationEffect(Angle(degrees: -90))
                .animation(.linear(duration: 0.5), value: batteryLevel)
            
            // Battery Level and Charging Icon
            VStack {
                Image(systemName: isCharging ? "bolt.fill" : "battery.100")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(isCharging ? .yellow : .white)
                    .shadow(radius: 5)
                    .accessibility(hidden: true)
                
                Text("\(Int(batteryLevel * 100))%")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .accessibility(label: Text("Battery level \(Int(batteryLevel * 100)) percent"))
            }
        }
    }
}

struct CircularBatteryView_Previews: PreviewProvider {
    static var previews: some View {
        CircularBatteryView(isCharging: true, batteryLevel: 0.75)
            .preferredColorScheme(.dark)
    }
}
