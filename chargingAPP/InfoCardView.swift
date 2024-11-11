//
//  InfoCardView.swift
//  chargingAPP
//
//  Created by yikang cheng on 2024/11/4.
//

import SwiftUI

struct InfoCardView: View {
    var title: String
    var value: String
    var icon: String
    var iconColor: Color
    
    var body: some View {
        HStack(spacing: 15) {
            // Icon
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(iconColor.opacity(0.2))
                )
                .shadow(color: iconColor.opacity(0.3), radius: 5, x: 0, y: 3)
                .accessibility(hidden: true)
            
            // Text Information
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .accessibility(addTraits: .isHeader)
                
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .fontWeight(.semibold)
                    .accessibility(label: Text("\(title): \(value)"))
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.black.opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 3)
    }
}

struct InfoCardView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            InfoCardView(title: "Charging Status", value: "Charging", icon: "bolt.fill", iconColor: .green)
            InfoCardView(title: "Estimated Time to Full", value: "1h 30m", icon: "clock.fill", iconColor: .blue)
            InfoCardView(title: "Thermal State", value: "Nominal", icon: "thermometer.sun.fill", iconColor: .orange)
        }
        .preferredColorScheme(.dark)
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
