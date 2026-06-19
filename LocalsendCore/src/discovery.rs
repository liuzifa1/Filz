use crate::http::dto::{ProtocolType, RegisterDto};
use crate::http::state::ClientInfo;
use crate::model::discovery::DeviceType;
use serde::{Deserialize, Serialize};
use socket2::{Domain, Protocol, Socket, Type};
use std::collections::HashMap;
use std::net::{IpAddr, Ipv4Addr, SocketAddrV4};
use std::sync::{Mutex, OnceLock};
use std::time::{Duration, Instant};
use tokio::sync::mpsc;

const MULTICAST_GROUP: Ipv4Addr = Ipv4Addr::new(224, 0, 0, 167);
const PEER_TTL: Duration = Duration::from_secs(60);

#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct DiscoveredDevice {
    pub alias: String,
    pub version: String,
    pub device_model: Option<String>,
    pub device_type: DeviceType,
    pub token: String,
    pub ip: String,
    pub port: u16,
    pub protocol: ProtocolType,
    pub download: bool,
}

struct PeerRecord {
    device: DiscoveredDevice,
    last_seen: Instant,
}

static DEVICES: OnceLock<Mutex<HashMap<String, PeerRecord>>> = OnceLock::new();

fn devices() -> &'static Mutex<HashMap<String, PeerRecord>> {
    DEVICES.get_or_init(|| Mutex::new(HashMap::new()))
}

pub(crate) fn record_register(payload: &RegisterDto, ip: IpAddr) {
    record(DiscoveredDevice {
        alias: payload.alias.clone(),
        version: payload.version.clone(),
        device_model: payload.device_model.clone(),
        device_type: payload.device_type.clone().unwrap_or(DeviceType::Desktop),
        token: payload.token.clone(),
        ip: ip.to_string(),
        port: payload.port,
        protocol: payload.protocol.clone(),
        download: payload.has_web_interface,
    });
}

fn record(device: DiscoveredDevice) {
    let key = if device.token.is_empty() {
        format!("{}@{}:{}", device.alias, device.ip, device.port)
    } else {
        device.token.clone()
    };
    devices().lock().unwrap().insert(
        key,
        PeerRecord {
            device,
            last_seen: Instant::now(),
        },
    );
}

pub(crate) fn devices_json() -> String {
    let mut devices = devices().lock().unwrap();
    devices.retain(|_, record| record.last_seen.elapsed() <= PEER_TTL);
    let mut snapshot = devices
        .values()
        .map(|record| record.device.clone())
        .collect::<Vec<_>>();
    snapshot.sort_by(|left, right| left.alias.to_lowercase().cmp(&right.alias.to_lowercase()));
    serde_json::to_string(&snapshot).unwrap_or_else(|_| "[]".to_string())
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct MulticastDto {
    alias: String,
    version: Option<String>,
    device_model: Option<String>,
    device_type: Option<String>,
    fingerprint: String,
    port: Option<u16>,
    protocol: Option<String>,
    #[serde(default)]
    download: bool,
    #[serde(default)]
    announcement: bool,
    #[serde(default)]
    announce: bool,
}

impl MulticastDto {
    fn into_device(self, ip: IpAddr, default_port: u16) -> DiscoveredDevice {
        DiscoveredDevice {
            alias: self.alias,
            version: self.version.unwrap_or_else(|| "1.0".to_string()),
            device_model: self.device_model,
            device_type: parse_device_type(self.device_type.as_deref()),
            token: self.fingerprint,
            ip: ip.to_string(),
            port: self.port.unwrap_or(default_port),
            protocol: parse_protocol(self.protocol.as_deref()),
            download: self.download,
        }
    }
}

fn parse_device_type(value: Option<&str>) -> DeviceType {
    match value.unwrap_or_default().to_ascii_lowercase().as_str() {
        "mobile" => DeviceType::Mobile,
        "web" => DeviceType::Web,
        "headless" => DeviceType::Headless,
        "server" => DeviceType::Server,
        _ => DeviceType::Desktop,
    }
}

fn parse_protocol(value: Option<&str>) -> ProtocolType {
    match value.unwrap_or("https").to_ascii_lowercase().as_str() {
        "http" => ProtocolType::Http,
        _ => ProtocolType::Https,
    }
}

pub(crate) async fn run(
    port: u16,
    info: ClientInfo,
    mut refresh_rx: mpsc::UnboundedReceiver<()>,
) -> anyhow::Result<()> {
    let socket = Socket::new(Domain::IPV4, Type::DGRAM, Some(Protocol::UDP))?;
    socket.set_reuse_address(true)?;
    #[cfg(any(
        target_os = "ios",
        target_os = "macos",
        target_os = "tvos",
        target_os = "watchos"
    ))]
    socket.set_reuse_port(true)?;
    socket.bind(&SocketAddrV4::new(Ipv4Addr::UNSPECIFIED, port).into())?;
    socket.join_multicast_v4(&MULTICAST_GROUP, &Ipv4Addr::UNSPECIFIED)?;
    socket.set_multicast_ttl_v4(1)?;
    socket.set_nonblocking(true)?;

    let socket = tokio::net::UdpSocket::from_std(socket.into())?;
    let announcement = multicast_payload(&info, port, true)?;
    let response = multicast_payload(&info, port, false)?;
    let target = SocketAddrV4::new(MULTICAST_GROUP, port);
    let mut interval = tokio::time::interval(Duration::from_secs(30));
    let mut buffer = vec![0_u8; 64 * 1024];

    let _ = socket.send_to(&announcement, target).await;

    loop {
        tokio::select! {
            result = socket.recv_from(&mut buffer) => {
                let (length, source) = result?;
                let Ok(dto) = serde_json::from_slice::<MulticastDto>(&buffer[..length]) else {
                    continue;
                };
                if dto.fingerprint == info.token {
                    continue;
                }

                let should_answer = dto.announcement || dto.announce;
                record(dto.into_device(source.ip(), port));
                if should_answer {
                    let _ = socket.send_to(&response, target).await;
                }
            }
            Some(()) = refresh_rx.recv() => {
                let _ = socket.send_to(&announcement, target).await;
            }
            _ = interval.tick() => {
                let _ = socket.send_to(&announcement, target).await;
            }
        }
    }
}

fn multicast_payload(info: &ClientInfo, port: u16, announcement: bool) -> anyhow::Result<Vec<u8>> {
    let device_type = match info.device_type.as_ref().unwrap_or(&DeviceType::Mobile) {
        DeviceType::Mobile => "mobile",
        DeviceType::Desktop => "desktop",
        DeviceType::Web => "web",
        DeviceType::Headless => "headless",
        DeviceType::Server => "server",
    };
    Ok(serde_json::to_vec(&serde_json::json!({
        "alias": info.alias,
        "version": info.version,
        "deviceModel": info.device_model,
        "deviceType": device_type,
        "fingerprint": info.token,
        "port": port,
        "protocol": "https",
        "download": false,
        "announcement": announcement,
        "announce": announcement
    }))?)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn decodes_upstream_multicast_payload() {
        let payload = br#"{"alias":"Desktop","version":"2.1","deviceModel":"Mac","deviceType":"desktop","fingerprint":"peer-token","port":53317,"protocol":"http","download":false,"announcement":true,"announce":true}"#;
        let dto: MulticastDto = serde_json::from_slice(payload).unwrap();
        let device = dto.into_device("192.168.1.5".parse().unwrap(), 53317);
        assert_eq!(device.alias, "Desktop");
        assert_eq!(device.device_type, DeviceType::Desktop);
        assert_eq!(device.protocol, ProtocolType::Http);
    }
}
