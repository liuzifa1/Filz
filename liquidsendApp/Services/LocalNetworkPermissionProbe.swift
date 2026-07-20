//
//  LocalNetworkPermissionProbe.swift
//  liquidsend
//

import Foundation
import Network

final class LocalNetworkPermissionProbe {
    enum Result {
        case allowed
        case denied
        case unableToConfirm
    }

    private static let serviceType = "_filz-permission._tcp"

    private let queue = DispatchQueue(label: "top.kitsune.filz.local-network-permission")
    private var browser: NWBrowser?
    private var listener: NWListener?
    private var completion: ((Result) -> Void)?
    private var hasCompleted = false

    func request(completion: @escaping (Result) -> Void) {
        queue.async { [weak self] in
            guard let self else { return }
            self.cancelCurrentRequest()
            self.completion = completion
            self.hasCompleted = false

            let parameters = NWParameters.tcp
            parameters.includePeerToPeer = true

            let browser = NWBrowser(
                for: .bonjour(type: Self.serviceType, domain: nil),
                using: parameters
            )
            browser.stateUpdateHandler = { [weak self] state in
                switch state {
                case .waiting(let error):
                    if Self.isPolicyDenied(error) {
                        self?.finish(with: .denied)
                    }
                case .failed(let error):
                    self?.finish(with: Self.isPolicyDenied(error) ? .denied : .unableToConfirm)
                default:
                    break
                }
            }

            do {
                let serviceName = "Filz Permission Probe \(UUID().uuidString)"
                let listener = try NWListener(using: parameters)
                listener.service = NWListener.Service(
                    name: serviceName,
                    type: Self.serviceType
                )
                listener.newConnectionHandler = { connection in
                    connection.cancel()
                }
                listener.stateUpdateHandler = { [weak self] state in
                    switch state {
                    case .waiting(let error):
                        if Self.isPolicyDenied(error) {
                            self?.finish(with: .denied)
                        }
                    case .failed(let error):
                        self?.finish(with: Self.isPolicyDenied(error) ? .denied : .unableToConfirm)
                    default:
                        break
                    }
                }
                browser.browseResultsChangedHandler = { [weak self] results, _ in
                    let foundProbe = results.contains { result in
                        guard case .service(let name, _, _, _) = result.endpoint else {
                            return false
                        }
                        return name == serviceName
                    }
                    if foundProbe {
                        self?.finish(with: .allowed)
                    }
                }
                self.listener = listener
                self.browser = browser
                listener.start(queue: self.queue)
                browser.start(queue: self.queue)
            } catch {
                self.finish(with: .unableToConfirm)
            }
        }
    }

    func cancel() {
        queue.async { [weak self] in
            self?.cancelCurrentRequest()
        }
    }

    private func finish(with result: Result) {
        guard !hasCompleted else { return }
        hasCompleted = true
        let completion = completion
        cancelCurrentRequest()
        DispatchQueue.main.async {
            completion?(result)
        }
    }

    private func cancelCurrentRequest() {
        browser?.stateUpdateHandler = nil
        browser?.browseResultsChangedHandler = nil
        browser?.cancel()
        browser = nil
        listener?.stateUpdateHandler = nil
        listener?.cancel()
        listener = nil
        completion = nil
    }

    private static func isPolicyDenied(_ error: NWError) -> Bool {
        switch error {
        case .dns(let code):
            // kDNSServiceErr_PolicyDenied from dns_sd.h.
            return code == -65_570
        case .posix(let code):
            return code == .EACCES
        default:
            return false
        }
    }
}
