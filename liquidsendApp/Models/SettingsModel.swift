//
//  SettingsModel.swift
//  liquidsend
//
//  Created by liu zifa1 on 1/23/26.
//

import Foundation
import SwiftData

enum AppDeviceIcon: String, CaseIterable, Identifiable, Codable {
    case iphone
    case pc
    case browser
    case cli
    case server
    
    var id: Self { self }
    
    // Title for each case
    var title: String {
        switch self {
        case .iphone: return "iPhone"
        case .pc: return "PC"
        case .browser: return "Browser"
        case .cli: return "CLI"
        case .server: return "Server"
        }
    }
    
    // System image for each case
    var systemImage: String {
        switch self {
        case .iphone: return "iphone"
        case .pc: return "desktopcomputer"
        case .browser: return "globe"
        case .cli: return "terminal"
        case .server: return "server.rack"
        }
    }
}

@Model
final class SettingsModel {
    var quickSave: Bool
    var quickSaveFavourites: Bool
    var requirePIN: Bool
    var receivePIN: String = ""
    var favouriteDeviceTokens: [String] = []
    var saveMediaToGallery: Bool
    var autoFinish: Bool
    var saveToHistory: Bool
    
    var userName: String
    
    var isAdvancedNetworkingOn: Bool
    var autoAcceptShareLink: Bool
    var selectedDeviceIcon: AppDeviceIcon
    var deviceModel: String
    var port: String
    var discoveryTimeout: Int
    var encryption: Bool
    
    init(
        quickSave: Bool = false,
        quickSaveFavourites: Bool = false,
        requirePIN: Bool = false,
        receivePIN: String = "",
        favouriteDeviceTokens: [String] = [],
        saveMediaToGallery: Bool = false,
        autoFinish: Bool = false,
        saveToHistory: Bool = true,
        userName: String = SettingsModel.defaultDeviceName(),
        isAdvancedNetworkingOn: Bool = false,
        autoAcceptShareLink: Bool = false,
        selectedDeviceIcon: AppDeviceIcon = .iphone,
        deviceModel: String = "",
        port: String = "53317",
        discoveryTimeout: Int = 500,
        encryption: Bool = false
    ) {
        self.quickSave = quickSave
        self.quickSaveFavourites = quickSaveFavourites
        self.requirePIN = requirePIN
        self.receivePIN = receivePIN
        self.favouriteDeviceTokens = favouriteDeviceTokens
        self.saveMediaToGallery = saveMediaToGallery
        self.autoFinish = autoFinish
        self.saveToHistory = saveToHistory
        self.userName = userName
        self.isAdvancedNetworkingOn = isAdvancedNetworkingOn
        self.autoAcceptShareLink = autoAcceptShareLink
        self.selectedDeviceIcon = selectedDeviceIcon
        self.deviceModel = deviceModel
        self.port = port
        self.discoveryTimeout = discoveryTimeout
        self.encryption = encryption
    }

    static func defaultDeviceName() -> String {
        "Filz!\(Int.random(in: 1000...9999))"
    }

    func isFavourite(_ device: LocalSendDevice) -> Bool {
        favouriteDeviceTokens.contains(device.id)
    }

    func toggleFavourite(_ device: LocalSendDevice) {
        if let index = favouriteDeviceTokens.firstIndex(of: device.id) {
            favouriteDeviceTokens.remove(at: index)
        } else {
            favouriteDeviceTokens.append(device.id)
        }
    }
}
