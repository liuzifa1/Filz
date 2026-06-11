//
//  LocalSendCoreClient.swift
//  liquidsend
//
//  Created by Codex on 6/10/26.
//
//  C FFI bridge to LocalSend Core. The value types it exchanges live in
//  Models/LocalSendModels.swift.
//

import Foundation
import LocalSendCore

enum LocalSendCoreClient {
    private static let tokenKey = "localsendCoreToken"

    static var isAvailable: Bool {
        localsendcore_is_available()
    }

    static var version: String {
        guard let versionPointer = localsendcore_version() else {
            return "Unavailable"
        }

        return String(cString: versionPointer)
    }

    static var isServerRunning: Bool {
        localsendcore_is_server_running()
    }

    static var lastError: String? {
        guard let errorPointer = localsendcore_last_error() else {
            return nil
        }

        let error = String(cString: errorPointer)
        return error.isEmpty ? nil : error
    }

    static func startServer(
        port: UInt16,
        alias: String,
        deviceModel: String,
        deviceType: UInt8
    ) -> String? {
        let result: Int32 = alias.withCString { aliasPointer in
            deviceModel.withCString { deviceModelPointer in
                token.withCString { tokenPointer in
                    localsendcore_start_server(
                        port,
                        aliasPointer,
                        deviceModelPointer,
                        deviceType,
                        tokenPointer
                    )
                }
            }
        }

        return result == 0 ? nil : lastError ?? "Unable to start LocalSend Core"
    }

    static func stopServer() {
        localsendcore_stop_server()
    }

    static func configureReceiveDirectory(_ url: URL) -> String? {
        let result = url.path.withCString { path in
            localsendcore_set_receive_directory(path)
        }
        return result == 0 ? nil : lastError ?? "Unable to configure receive directory"
    }

    static var identityToken: String {
        token
    }

    nonisolated static func sendFile(
        to device: LocalSendDevice,
        senderAlias: String,
        senderPort: UInt16,
        senderDeviceModel: String,
        senderDeviceType: UInt8,
        senderToken: String,
        filePath: String,
        fileName: String,
        fileType: String
    ) -> String? {
        let result: Int32 = device.ip.withCString { targetIP in
            device.protocol.withCString { targetProtocol in
                senderAlias.withCString { alias in
                    senderDeviceModel.withCString { model in
                        senderToken.withCString { token in
                            filePath.withCString { path in
                                fileName.withCString { name in
                                    fileType.withCString { mime in
                                        localsendcore_send_file(
                                            targetIP,
                                            device.port,
                                            targetProtocol,
                                            alias,
                                            senderPort,
                                            model,
                                            senderDeviceType,
                                            token,
                                            path,
                                            name,
                                            mime
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        guard result != 0, let pointer = localsendcore_last_error() else {
            return nil
        }
        let error = String(cString: pointer)
        return error.isEmpty ? "Unable to send file" : error
    }

    nonisolated static func sendFiles(
        _ files: [LocalSendFile],
        to device: LocalSendDevice,
        senderAlias: String,
        senderPort: UInt16,
        senderDeviceModel: String,
        senderDeviceType: UInt8,
        senderToken: String
    ) -> String? {
        guard let data = try? JSONEncoder().encode(files),
              let filesJSON = String(data: data, encoding: .utf8) else {
            return "Unable to encode selected files"
        }
        let result: Int32 = device.ip.withCString { targetIP in
            device.protocol.withCString { targetProtocol in
                device.alias.withCString { targetAlias in
                    senderAlias.withCString { alias in
                        senderDeviceModel.withCString { model in
                            senderToken.withCString { token in
                                filesJSON.withCString { files in
                                    localsendcore_send_files_json(
                                        targetIP,
                                        device.port,
                                        targetProtocol,
                                        targetAlias,
                                        alias,
                                        senderPort,
                                        model,
                                        senderDeviceType,
                                        token,
                                        files
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
        guard result != 0, let pointer = localsendcore_last_error() else {
            return nil
        }
        let error = String(cString: pointer)
        return error.isEmpty ? "Unable to send files" : error
    }

    static var pendingReceiveRequest: IncomingLocalSendRequest? {
        decodeOwnedJSON(localsendcore_pending_receive_json(), as: IncomingLocalSendRequest.self)
    }

    static var sendProgress: LocalSendTransferProgress? {
        decodeOwnedJSON(localsendcore_send_progress_json(), as: LocalSendTransferProgress.self)
    }

    static var receiveProgress: LocalSendTransferProgress? {
        decodeOwnedJSON(localsendcore_receive_progress_json(), as: LocalSendTransferProgress.self)
    }

    static func decideReceive(requestID: String, accepted: Bool) -> String? {
        let result = requestID.withCString { requestID in
            localsendcore_decide_receive(requestID, accepted)
        }
        return result == 0 ? nil : lastError ?? "Unable to answer receive request"
    }

    static func refreshDiscovery() {
        localsendcore_refresh_discovery()
    }

    static var discoveredDevices: [LocalSendDevice] {
        guard let pointer = localsendcore_discovered_devices_json() else {
            return []
        }
        defer { localsendcore_string_free(pointer) }

        let data = Data(String(cString: pointer).utf8)
        return (try? JSONDecoder().decode([LocalSendDevice].self, from: data)) ?? []
    }

    private static func decodeOwnedJSON<T: Decodable>(
        _ pointer: UnsafeMutablePointer<CChar>?,
        as type: T.Type
    ) -> T? {
        guard let pointer else { return nil }
        defer { localsendcore_string_free(pointer) }
        return try? JSONDecoder().decode(T.self, from: Data(String(cString: pointer).utf8))
    }

    private static var token: String {
        if let token = UserDefaults.standard.string(forKey: tokenKey) {
            return token
        }

        let token = UUID().uuidString
        UserDefaults.standard.set(token, forKey: tokenKey)
        return token
    }
}
