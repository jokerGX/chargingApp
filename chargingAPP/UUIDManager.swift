//
//  UUIDManager.swift
//  chargingAPP
//
//  Created by yikang cheng on 2024/11/11.
//


// UUIDManager.swift

import Foundation
import Security

class UUIDManager {
    static let shared = UUIDManager()
    
    private let service = "com.yourapp.uniqueid"
    private let account = "uniqueid"
    
    var uuid: String {
        if let existingUUID = getUUID() {
            return existingUUID
        } else {
            let newUUID = UUID().uuidString
            saveUUID(newUUID)
            return newUUID
        }
    }
    
    private func getUUID() -> String? {
        let query: [String: Any] = [
            kSecClass as String       : kSecClassGenericPassword,
            kSecAttrService as String : service,
            kSecAttrAccount as String : account,
            kSecReturnData as String  : kCFBooleanTrue!,
            kSecMatchLimit as String  : kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject? = nil
        let status: OSStatus = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let data = dataTypeRef as? Data, let uuid = String(data: data, encoding: .utf8) {
            return uuid
        }
        return nil
    }
    
    private func saveUUID(_ uuid: String) {
        if let data = uuid.data(using: .utf8) {
            let query: [String: Any] = [
                kSecClass as String       : kSecClassGenericPassword,
                kSecAttrService as String : service,
                kSecAttrAccount as String : account,
                kSecValueData as String   : data
            ]
            
            SecItemAdd(query as CFDictionary, nil)
        }
    }
}
