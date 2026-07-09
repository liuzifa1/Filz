import Darwin
import Foundation

enum NetworkInterfaceAddresses {
    /// A permission-free identifier for the current network: the /24 subnet
    /// prefix of the primary private IPv4 (e.g. "192.168.1"). iOS gates the
    /// Wi-Fi SSID behind Location permission, so the subnet is the closest
    /// stand-in a file-transfer app can read without prompting. Favourites are
    /// keyed on this so a device known at home doesn't clutter the list at the
    /// office.
    static func networkKey(from addresses: [String]) -> String {
        let privatePrefixes = ["192.168.", "10.", "172.16.", "172.17.", "172.18.",
                               "172.19.", "172.20.", "172.21.", "172.22.", "172.23.",
                               "172.24.", "172.25.", "172.26.", "172.27.", "172.28.",
                               "172.29.", "172.30.", "172.31."]
        let candidate = addresses.first { address in
            privatePrefixes.contains { address.hasPrefix($0) }
        } ?? addresses.first
        guard let candidate else { return "unknown" }
        let octets = candidate.split(separator: ".")
        guard octets.count == 4 else { return "unknown" }
        return octets.prefix(3).joined(separator: ".")
    }

    static var localIPv4: [String] {
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let first = pointer else { return [] }
        defer { freeifaddrs(pointer) }

        var addresses: [String] = []
        for interface in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let flags = Int32(interface.pointee.ifa_flags)
            guard flags & IFF_UP != 0,
                  flags & IFF_LOOPBACK == 0,
                  let address = interface.pointee.ifa_addr,
                  address.pointee.sa_family == UInt8(AF_INET) else {
                continue
            }

            var ipv4 = address.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr }
            var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            guard inet_ntop(AF_INET, &ipv4, &buffer, socklen_t(INET_ADDRSTRLEN)) != nil else { continue }
            let value = String(cString: buffer)
            if !addresses.contains(value) {
                addresses.append(value)
            }
        }
        return addresses.sorted()
    }
}
