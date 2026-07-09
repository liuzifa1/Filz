//
//  FavouriteDevice.swift
//  liquidsend
//
//  A persisted, network-keyed snapshot of a favourited device so the Send tab
//  can list known devices — with an online/offline badge — even when live
//  discovery turns up nothing.
//

import Foundation
import SwiftData

@Model
final class FavouriteDevice {
    var token: String
    var alias: String
    var deviceModel: String?
    var deviceType: String
    var ip: String
    var port: Int
    var networkProtocol: String
    // The subnet the device was last seen on; see NetworkInterfaceAddresses.
    var networkKey: String
    var lastSeen: Date

    init(
        token: String,
        alias: String,
        deviceModel: String?,
        deviceType: String,
        ip: String,
        port: Int,
        networkProtocol: String,
        networkKey: String,
        lastSeen: Date = .now
    ) {
        self.token = token
        self.alias = alias
        self.deviceModel = deviceModel
        self.deviceType = deviceType
        self.ip = ip
        self.port = port
        self.networkProtocol = networkProtocol
        self.networkKey = networkKey
        self.lastSeen = lastSeen
    }

    var systemImage: String {
        switch deviceType.lowercased() {
        case "mobile": "iphone"
        case "web": "globe"
        case "headless": "terminal"
        case "server": "server.rack"
        default: "desktopcomputer"
        }
    }

    var endpoint: String {
        "\(networkProtocol.lowercased())://\(ip):\(port)"
    }

    /// Rebuilds a LocalSendDevice from the snapshot so an offline favourite can
    /// still be selected as a send target (best-effort via the last-known IP).
    func makeDevice() -> LocalSendDevice {
        LocalSendDevice(
            alias: alias,
            version: "2.1",
            deviceModel: deviceModel,
            deviceType: deviceType,
            token: token,
            ip: ip,
            port: UInt16(clamping: port),
            protocol: networkProtocol,
            download: false
        )
    }
}

enum FavouriteStore {
    /// Refreshes (or creates) the snapshot for every currently-visible
    /// favourite on the current network, so each network learns a device's
    /// address the first time it's seen there and keeps it fresh afterwards.
    static func syncSnapshots(
        devices: [LocalSendDevice],
        favouriteTokens: Set<String>,
        networkKey: String,
        context: ModelContext
    ) {
        guard !networkKey.isEmpty, networkKey != "unknown" else { return }
        let existing = (try? context.fetch(FetchDescriptor<FavouriteDevice>())) ?? []
        var changed = false
        for device in devices where favouriteTokens.contains(device.id) {
            if let record = existing.first(where: { $0.token == device.id && $0.networkKey == networkKey }) {
                record.alias = device.alias
                record.deviceModel = device.deviceModel
                record.deviceType = device.deviceType
                record.ip = device.ip
                record.port = Int(device.port)
                record.networkProtocol = device.protocol
                record.lastSeen = .now
            } else {
                context.insert(FavouriteDevice(
                    token: device.id,
                    alias: device.alias,
                    deviceModel: device.deviceModel,
                    deviceType: device.deviceType,
                    ip: device.ip,
                    port: Int(device.port),
                    networkProtocol: device.protocol,
                    networkKey: networkKey
                ))
            }
            changed = true
        }
        if changed {
            try? context.save()
        }
    }

    /// Drops every snapshot for a device across all networks — used when the
    /// device is unfavourited (a global action keyed by token).
    static func removeSnapshots(token: String, context: ModelContext) {
        let records = (try? context.fetch(FetchDescriptor<FavouriteDevice>())) ?? []
        var changed = false
        for record in records where record.token == token {
            context.delete(record)
            changed = true
        }
        if changed {
            try? context.save()
        }
    }
}
