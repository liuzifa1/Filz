#[cfg(feature = "http")]
use futures_util::StreamExt;
#[cfg(feature = "http")]
use serde::{Deserialize, Serialize};
use std::ffi::{c_char, CStr, CString};
#[cfg(feature = "http")]
use std::sync::atomic::{AtomicBool, Ordering};
#[cfg(feature = "http")]
use std::sync::Arc;
use std::sync::{Mutex, OnceLock};
#[cfg(feature = "http")]
use std::thread::JoinHandle;
#[cfg(feature = "http")]
use tokio::io::AsyncReadExt;

#[cfg(feature = "crypto")]
pub mod crypto;
#[cfg(feature = "http")]
mod discovery;
#[cfg(feature = "http")]
pub mod http;
pub mod model;
#[cfg(feature = "http")]
mod receive;
#[cfg(feature = "http")]
mod tls_identity;
pub(crate) mod util;
pub mod webrtc;

const LOCALSENDCORE_VERSION: &[u8] = b"0.1.0\0";

#[cfg(feature = "http")]
struct ServerState {
    stop_tx: Option<tokio::sync::oneshot::Sender<()>>,
    discovery_tx: Option<tokio::sync::mpsc::UnboundedSender<()>>,
    thread: Option<JoinHandle<()>>,
    running: Arc<AtomicBool>,
}

#[cfg(feature = "http")]
impl ServerState {
    fn new() -> Self {
        Self {
            stop_tx: None,
            discovery_tx: None,
            thread: None,
            running: Arc::new(AtomicBool::new(false)),
        }
    }
}

#[cfg(feature = "http")]
static SERVER_STATE: OnceLock<Mutex<ServerState>> = OnceLock::new();
static LAST_ERROR: OnceLock<Mutex<CString>> = OnceLock::new();

#[cfg(feature = "http")]
#[derive(Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
struct SendFileInput {
    file_path: String,
    file_name: String,
    file_type: String,
    #[serde(default)]
    preview: Option<String>,
}

#[cfg(feature = "http")]
#[derive(Clone, Default, Serialize)]
#[serde(rename_all = "camelCase")]
struct SendProgress {
    status: String,
    started_at_millis: Option<u64>,
    target_alias: String,
    target_ip: String,
    target_port: u16,
    target_protocol: String,
    current_file: Option<String>,
    sent_bytes: u64,
    total_bytes: u64,
    completed_files: usize,
    total_files: usize,
    #[serde(skip_serializing_if = "Option::is_none")]
    text_message: Option<String>,
    error: Option<String>,
}

#[cfg(feature = "http")]
static SEND_PROGRESS: OnceLock<Mutex<SendProgress>> = OnceLock::new();
#[cfg(feature = "http")]
static SEND_CANCEL_REQUESTED: AtomicBool = AtomicBool::new(false);

#[cfg(feature = "http")]
fn send_progress() -> &'static Mutex<SendProgress> {
    SEND_PROGRESS.get_or_init(|| Mutex::new(SendProgress::default()))
}

#[cfg(feature = "http")]
fn update_send_progress(update: impl FnOnce(&mut SendProgress)) {
    update(
        &mut send_progress()
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner),
    );
}

#[cfg(feature = "http")]
fn unix_time_millis() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|duration| duration.as_millis() as u64)
        .unwrap_or(0)
}

fn last_error() -> &'static Mutex<CString> {
    LAST_ERROR.get_or_init(|| Mutex::new(CString::new("").unwrap()))
}

fn set_last_error(message: impl Into<String>) {
    let message = message.into().replace('\0', " ");
    *last_error()
        .lock()
        .unwrap_or_else(std::sync::PoisonError::into_inner) = CString::new(message).unwrap();
}

fn read_c_string(pointer: *const c_char, field: &str) -> Result<String, String> {
    if pointer.is_null() {
        return Err(format!("{field} is required"));
    }

    unsafe { CStr::from_ptr(pointer) }
        .to_str()
        .map(str::to_owned)
        .map_err(|_| format!("{field} must be valid UTF-8"))
}

#[no_mangle]
pub extern "C" fn localsendcore_version() -> *const c_char {
    LOCALSENDCORE_VERSION.as_ptr().cast()
}

#[no_mangle]
pub extern "C" fn localsendcore_is_available() -> bool {
    true
}

#[no_mangle]
pub extern "C" fn localsendcore_last_error() -> *const c_char {
    last_error()
        .lock()
        .unwrap_or_else(std::sync::PoisonError::into_inner)
        .as_ptr()
}

#[no_mangle]
pub extern "C" fn localsendcore_clear_last_error() {
    set_last_error("");
}

#[no_mangle]
pub extern "C" fn localsendcore_string_free(pointer: *mut c_char) {
    if pointer.is_null() {
        return;
    }
    unsafe {
        drop(CString::from_raw(pointer));
    }
}

#[cfg(feature = "http")]
#[no_mangle]
pub extern "C" fn localsendcore_discovered_devices_json() -> *mut c_char {
    CString::new(discovery::devices_json()).unwrap().into_raw()
}

#[cfg(feature = "http")]
#[no_mangle]
pub extern "C" fn localsendcore_refresh_discovery() {
    let Some(state) = SERVER_STATE.get() else {
        return;
    };
    if let Some(sender) = &state.lock().unwrap().discovery_tx {
        let _ = sender.send(());
    }
}

#[cfg(feature = "http")]
#[no_mangle]
pub extern "C" fn localsendcore_set_receive_directory(path: *const c_char) -> i32 {
    let result = read_c_string(path, "receive directory").and_then(receive::set_directory);
    match result {
        Ok(()) => 0,
        Err(error) => {
            set_last_error(error);
            -1
        }
    }
}

#[cfg(feature = "http")]
#[no_mangle]
pub extern "C" fn localsendcore_set_receive_pin(pin: *const c_char) -> i32 {
    let result = if pin.is_null() {
        Ok(None)
    } else {
        read_c_string(pin, "receive PIN").map(Some)
    };
    match result {
        Ok(pin) => {
            receive::set_pin(pin);
            set_last_error("");
            0
        }
        Err(error) => {
            set_last_error(error);
            -1
        }
    }
}

#[cfg(feature = "http")]
#[no_mangle]
pub extern "C" fn localsendcore_configure_tls_identity(
    directory: *const c_char,
    common_name: *const c_char,
) -> i32 {
    let result = read_c_string(directory, "TLS identity directory").and_then(|directory| {
        let common_name = read_c_string(common_name, "TLS identity name")?;
        tls_identity::configure(std::path::Path::new(&directory), &common_name)
            .map_err(|error| error.to_string())
    });
    match result {
        Ok(()) => {
            set_last_error("");
            0
        }
        Err(error) => {
            set_last_error(error);
            -1
        }
    }
}

#[cfg(feature = "http")]
fn owned_json(value: String) -> *mut c_char {
    CString::new(value).unwrap().into_raw()
}

#[cfg(feature = "http")]
#[no_mangle]
pub extern "C" fn localsendcore_pending_receive_json() -> *mut c_char {
    owned_json(receive::pending_json())
}

#[cfg(feature = "http")]
#[no_mangle]
pub extern "C" fn localsendcore_receive_progress_json() -> *mut c_char {
    owned_json(receive::progress_json())
}

#[cfg(feature = "http")]
#[no_mangle]
pub extern "C" fn localsendcore_send_progress_json() -> *mut c_char {
    let progress = send_progress()
        .lock()
        .unwrap_or_else(std::sync::PoisonError::into_inner)
        .clone();
    owned_json(serde_json::to_string(&progress).unwrap_or_else(|_| "{}".to_string()))
}

#[cfg(feature = "http")]
#[no_mangle]
pub extern "C" fn localsendcore_decide_receive(request_id: *const c_char, accepted: bool) -> i32 {
    let result = read_c_string(request_id, "request id")
        .and_then(|request_id| receive::decide(&request_id, accepted));
    match result {
        Ok(()) => 0,
        Err(error) => {
            set_last_error(error);
            -1
        }
    }
}

#[cfg(feature = "http")]
#[no_mangle]
pub extern "C" fn localsendcore_cancel_send() {
    SEND_CANCEL_REQUESTED.store(true, Ordering::SeqCst);
    update_send_progress(|progress| {
        progress.status = "canceled".to_string();
        progress.current_file = None;
        progress.error = None;
    });
}

#[cfg(feature = "http")]
#[no_mangle]
pub extern "C" fn localsendcore_cancel_receive() {
    receive::cancel_current();
}

#[cfg(feature = "http")]
#[no_mangle]
pub extern "C" fn localsendcore_send_file(
    target_ip: *const c_char,
    target_port: u16,
    target_protocol: *const c_char,
    sender_alias: *const c_char,
    sender_port: u16,
    sender_device_model: *const c_char,
    sender_device_type: u8,
    sender_token: *const c_char,
    file_path: *const c_char,
    file_name: *const c_char,
    file_type: *const c_char,
) -> i32 {
    SEND_CANCEL_REQUESTED.store(false, Ordering::SeqCst);
    let result = (|| -> Result<(), String> {
        let target_ip = read_c_string(target_ip, "target IP")?;
        let target_protocol = read_c_string(target_protocol, "target protocol")?;
        let sender_alias = read_c_string(sender_alias, "sender alias")?;
        let sender_device_model = read_c_string(sender_device_model, "sender device model")?;
        let sender_token = read_c_string(sender_token, "sender token")?;
        let file_path = read_c_string(file_path, "file path")?;
        let file_name = read_c_string(file_name, "file name")?;
        let file_type = read_c_string(file_type, "file type")?;

        if target_port == 0 || sender_port == 0 {
            return Err("ports must be between 1 and 65535".to_string());
        }

        let protocol = match target_protocol.to_ascii_lowercase().as_str() {
            "http" => crate::http::dto::ProtocolType::Http,
            "https" => crate::http::dto::ProtocolType::Https,
            _ => return Err(format!("unsupported protocol: {target_protocol}")),
        };
        let device_type = match sender_device_type {
            1 => crate::model::discovery::DeviceType::Desktop,
            2 => crate::model::discovery::DeviceType::Web,
            3 => crate::model::discovery::DeviceType::Headless,
            4 => crate::model::discovery::DeviceType::Server,
            _ => crate::model::discovery::DeviceType::Mobile,
        };
        send_files_blocking(
            target_ip,
            target_port,
            protocol.clone(),
            sender_alias,
            sender_port,
            protocol,
            sender_device_model,
            device_type,
            sender_token,
            "LocalSend device".to_string(),
            None,
            vec![SendFileInput {
                file_path,
                file_name,
                file_type,
                preview: None,
            }],
        )
    })();

    match result {
        Ok(()) => {
            set_last_error("");
            0
        }
        Err(error) => {
            set_last_error(error);
            -1
        }
    }
}

#[cfg(feature = "http")]
#[no_mangle]
pub extern "C" fn localsendcore_send_files_json(
    target_ip: *const c_char,
    target_port: u16,
    target_protocol: *const c_char,
    target_alias: *const c_char,
    target_pin: *const c_char,
    sender_alias: *const c_char,
    sender_port: u16,
    sender_protocol: *const c_char,
    sender_device_model: *const c_char,
    sender_device_type: u8,
    sender_token: *const c_char,
    files_json: *const c_char,
) -> i32 {
    SEND_CANCEL_REQUESTED.store(false, Ordering::SeqCst);
    let result = (|| -> Result<(), String> {
        let target_ip = read_c_string(target_ip, "target IP")?;
        let target_protocol = read_c_string(target_protocol, "target protocol")?;
        let target_alias = read_c_string(target_alias, "target alias")?;
        let target_pin = if target_pin.is_null() {
            None
        } else {
            Some(read_c_string(target_pin, "target PIN")?).filter(|pin| !pin.is_empty())
        };
        let sender_alias = read_c_string(sender_alias, "sender alias")?;
        let sender_protocol = read_c_string(sender_protocol, "sender protocol")?;
        let sender_device_model = read_c_string(sender_device_model, "sender device model")?;
        let sender_token = read_c_string(sender_token, "sender token")?;
        let files_json = read_c_string(files_json, "files JSON")?;
        let files: Vec<SendFileInput> = serde_json::from_str(&files_json)
            .map_err(|error| format!("Invalid files JSON: {error}"))?;
        if files.is_empty() {
            return Err("Choose at least one file".to_string());
        }
        let protocol = match target_protocol.to_ascii_lowercase().as_str() {
            "http" => crate::http::dto::ProtocolType::Http,
            "https" => crate::http::dto::ProtocolType::Https,
            _ => return Err(format!("unsupported protocol: {target_protocol}")),
        };
        let sender_protocol = match sender_protocol.to_ascii_lowercase().as_str() {
            "http" => crate::http::dto::ProtocolType::Http,
            "https" => crate::http::dto::ProtocolType::Https,
            _ => return Err(format!("unsupported sender protocol: {sender_protocol}")),
        };
        let device_type = match sender_device_type {
            1 => crate::model::discovery::DeviceType::Desktop,
            2 => crate::model::discovery::DeviceType::Web,
            3 => crate::model::discovery::DeviceType::Headless,
            4 => crate::model::discovery::DeviceType::Server,
            _ => crate::model::discovery::DeviceType::Mobile,
        };
        send_files_blocking(
            target_ip,
            target_port,
            protocol,
            sender_alias,
            sender_port,
            sender_protocol,
            sender_device_model,
            device_type,
            sender_token,
            target_alias,
            target_pin,
            files,
        )
    })();
    match result {
        Ok(()) => {
            set_last_error("");
            0
        }
        Err(error) => {
            if SEND_CANCEL_REQUESTED.load(Ordering::SeqCst) {
                update_send_progress(|progress| {
                    progress.status = "canceled".to_string();
                    progress.error = None;
                });
            } else {
                update_send_progress(|progress| {
                    progress.status = "failed".to_string();
                    progress.error = Some(error.clone());
                });
            }
            set_last_error(error);
            -1
        }
    }
}

#[cfg(feature = "http")]
fn send_files_blocking(
    target_ip: String,
    target_port: u16,
    protocol: crate::http::dto::ProtocolType,
    sender_alias: String,
    sender_port: u16,
    sender_protocol: crate::http::dto::ProtocolType,
    sender_device_model: String,
    sender_device_type: crate::model::discovery::DeviceType,
    sender_token: String,
    target_alias: String,
    target_pin: Option<String>,
    files: Vec<SendFileInput>,
) -> Result<(), String> {
    if target_port == 0 || sender_port == 0 {
        return Err("ports must be between 1 and 65535".to_string());
    }
    let runtime = tokio::runtime::Builder::new_multi_thread()
        .worker_threads(2)
        .enable_all()
        .build()
        .map_err(|error| error.to_string())?;
    runtime
        .block_on(send_files_v2(
            target_ip,
            target_port,
            protocol,
            sender_alias,
            sender_port,
            sender_protocol,
            sender_device_model,
            sender_device_type,
            sender_token,
            target_alias,
            target_pin,
            files,
        ))
        .map_err(|error| error.to_string())
}

#[cfg(feature = "http")]
async fn send_files_v2(
    target_ip: String,
    target_port: u16,
    protocol: crate::http::dto::ProtocolType,
    sender_alias: String,
    sender_port: u16,
    sender_protocol: crate::http::dto::ProtocolType,
    sender_device_model: String,
    sender_device_type: crate::model::discovery::DeviceType,
    sender_token: String,
    target_alias: String,
    target_pin: Option<String>,
    files: Vec<SendFileInput>,
) -> anyhow::Result<()> {
    let mut prepared_files = Vec::new();
    for input in files {
        let metadata = tokio::fs::metadata(&input.file_path).await?;
        if !metadata.is_file() {
            return Err(anyhow::anyhow!("{} is not a file", input.file_name));
        }
        prepared_files.push((uuid::Uuid::new_v4().to_string(), input, metadata.len()));
    }
    let is_text_message = prepared_files.len() == 1
        && prepared_files.iter().all(|(_, input, _)| {
            input
                .preview
                .as_ref()
                .is_some_and(|preview| !preview.is_empty())
                && input.file_type.starts_with("text/")
        });
    let text_message = is_text_message
        .then(|| {
            prepared_files
                .first()
                .and_then(|(_, input, _)| input.preview.clone())
        })
        .flatten();
    let total_bytes = prepared_files.iter().map(|(_, _, size)| size).sum();
    update_send_progress(|progress| {
        *progress = SendProgress {
            status: "waiting".to_string(),
            started_at_millis: Some(unix_time_millis()),
            target_alias: target_alias.clone(),
            target_ip: target_ip.clone(),
            target_port,
            target_protocol: protocol.as_str().to_string(),
            total_bytes,
            total_files: prepared_files.len(),
            text_message: text_message.clone(),
            ..SendProgress::default()
        };
    });
    let _ = rustls::crypto::ring::default_provider().install_default();
    let mut client_builder = reqwest::Client::builder()
        .connect_timeout(std::time::Duration::from_secs(5))
        .timeout(std::time::Duration::from_secs(300));
    if protocol == crate::http::dto::ProtocolType::Https {
        let tls_identity = tls_identity::current()?;
        client_builder =
            client_builder.use_preconfigured_tls(crate::http::client::local_send_tls_config(
                &tls_identity.private_key,
                &tls_identity.cert,
            )?);
    }
    let client = client_builder.build()?;
    let info = crate::http::dto::RegisterDto {
        alias: sender_alias,
        version: "2.1".to_string(),
        device_model: (!sender_device_model.is_empty()).then_some(sender_device_model),
        device_type: Some(sender_device_type),
        token: sender_token,
        port: sender_port,
        protocol: sender_protocol,
        has_web_interface: false,
    };
    let request = crate::http::dto::PrepareUploadRequestDto {
        info,
        files: prepared_files
            .iter()
            .map(|(id, input, size)| {
                (
                    id.clone(),
                    crate::model::transfer::FileDto {
                        id: id.clone(),
                        file_name: input.file_name.clone(),
                        size: *size,
                        file_type: input.file_type.clone(),
                        sha256: None,
                        preview: input.preview.clone(),
                        metadata: None,
                    },
                )
            })
            .collect(),
    };
    let host = format_host(&target_ip);
    let base_url = format!(
        "{}://{}:{}/api/localsend/v2",
        protocol.as_str(),
        host,
        target_port
    );
    let mut prepare_url = reqwest::Url::parse(&format!("{base_url}/prepare-upload"))?;
    if let Some(pin) = target_pin {
        prepare_url.query_pairs_mut().append_pair("pin", &pin);
    }
    let prepare_request = client.post(prepare_url).json(&request).send();
    let response = tokio::select! {
        response = prepare_request => match response {
            Ok(response) => response,
            Err(error) => return Err(error.into()),
        },
        _ = wait_for_send_cancel() => {
            let _ = client.post(format!("{base_url}/cancel")).send().await;
            return Err(anyhow::anyhow!("Transfer canceled"));
        }
    };

    if response.status() == reqwest::StatusCode::NO_CONTENT {
        // Per the LocalSend protocol, 204 means "finished — no file transfer
        // needed": the receiver consumed the transfer during prepare-upload
        // (our receiver's text-message shortcut). Rejection is 403.
        update_send_progress(|progress| {
            progress.status = "finished".to_string();
            progress.current_file = None;
            progress.sent_bytes = total_bytes;
            progress.completed_files = progress.total_files;
        });
        return Ok(());
    }
    if response.status() == reqwest::StatusCode::FORBIDDEN {
        return Err(anyhow::anyhow!("The recipient did not accept the files"));
    }
    if response.status() != reqwest::StatusCode::OK {
        return Err(http_response_error(response).await);
    }
    let prepared = response
        .json::<crate::http::dto::PrepareUploadResponseDto>()
        .await?;
    let accepted_total_bytes = prepared_files
        .iter()
        .filter(|(id, _, _)| prepared.files.contains_key(id))
        .map(|(_, _, size)| size)
        .sum();
    update_send_progress(|progress| {
        progress.total_bytes = accepted_total_bytes;
        progress.total_files = prepared.files.len();
    });
    update_send_progress(|progress| progress.status = "sending".to_string());
    for (file_id, input, file_size) in prepared_files {
        if SEND_CANCEL_REQUESTED.load(Ordering::SeqCst) {
            let _ = client
                .post(format!("{base_url}/cancel"))
                .query(&[("sessionId", prepared.session_id.clone())])
                .send()
                .await;
            return Err(anyhow::anyhow!("Transfer canceled"));
        }
        let Some(file_token) = prepared.files.get(&file_id).cloned() else {
            continue;
        };
        update_send_progress(|progress| progress.current_file = Some(input.file_name.clone()));
        let (tx, rx) = tokio::sync::mpsc::channel::<Vec<u8>>(4);
        let file_path = input.file_path.clone();
        tokio::spawn(async move {
            let Ok(mut file) = tokio::fs::File::open(file_path).await else {
                return;
            };
            let mut buffer = vec![0_u8; 64 * 1024];
            loop {
                if SEND_CANCEL_REQUESTED.load(Ordering::SeqCst) {
                    break;
                }
                match file.read(&mut buffer).await {
                    Ok(0) => break,
                    Ok(length) => {
                        if tx.send(buffer[..length].to_vec()).await.is_err() {
                            break;
                        }
                        update_send_progress(|progress| progress.sent_bytes += length as u64);
                    }
                    Err(_) => break,
                }
            }
        });
        let stream =
            tokio_stream::wrappers::ReceiverStream::new(rx).map(Ok::<Vec<u8>, std::io::Error>);
        let upload_request = client
            .post(format!("{base_url}/upload"))
            .query(&[
                ("sessionId", prepared.session_id.clone()),
                ("fileId", file_id),
                ("token", file_token),
            ])
            .header(reqwest::header::CONTENT_LENGTH, file_size)
            .header(reqwest::header::CONTENT_TYPE, input.file_type)
            .body(reqwest::Body::wrap_stream(stream))
            .send();
        let response = tokio::select! {
            response = upload_request => response?,
            _ = wait_for_send_cancel() => {
                let _ = client
                    .post(format!("{base_url}/cancel"))
                    .query(&[("sessionId", prepared.session_id.clone())])
                    .send()
                    .await;
                return Err(anyhow::anyhow!("Transfer canceled"));
            }
        };
        if response.status() != reqwest::StatusCode::OK {
            return Err(http_response_error(response).await);
        }
        update_send_progress(|progress| progress.completed_files += 1);
    }
    update_send_progress(|progress| {
        progress.status = "finished".to_string();
        progress.current_file = None;
    });
    Ok(())
}

#[cfg(feature = "http")]
async fn wait_for_send_cancel() {
    while !SEND_CANCEL_REQUESTED.load(Ordering::SeqCst) {
        tokio::time::sleep(std::time::Duration::from_millis(50)).await;
    }
}

#[cfg(feature = "http")]
fn format_host(host: &str) -> String {
    if host.contains(':') {
        format!("[{host}]")
    } else {
        host.to_string()
    }
}

#[cfg(feature = "http")]
async fn http_response_error(response: reqwest::Response) -> anyhow::Error {
    let status = response.status().as_u16();
    let body = response.text().await.unwrap_or_default();
    let message = serde_json::from_str::<crate::http::dto::ErrorResponse>(&body)
        .map(|error| error.message)
        .unwrap_or(body);
    anyhow::anyhow!(if message.is_empty() {
        format!("LocalSend request failed with status {status}")
    } else {
        format!("LocalSend request failed [{status}]: {message}")
    })
}

#[cfg(feature = "http")]
#[no_mangle]
pub extern "C" fn localsendcore_start_server(
    port: u16,
    alias: *const c_char,
    device_model: *const c_char,
    device_type: u8,
    token: *const c_char,
    use_tls: bool,
) -> i32 {
    let alias = match read_c_string(alias, "alias") {
        Ok(value) => value,
        Err(error) => {
            set_last_error(error);
            return -1;
        }
    };
    let device_model = match read_c_string(device_model, "device model") {
        Ok(value) => value,
        Err(error) => {
            set_last_error(error);
            return -1;
        }
    };
    let token = match read_c_string(token, "token") {
        Ok(value) => value,
        Err(error) => {
            set_last_error(error);
            return -1;
        }
    };

    if port == 0 {
        set_last_error("port must be between 1 and 65535");
        return -1;
    }

    let tls_config = if use_tls {
        match tls_identity::current() {
            Ok(identity) => Some(crate::http::server::TlsConfig {
                cert: identity.cert,
                private_key: identity.private_key,
            }),
            Err(error) => {
                set_last_error(error.to_string());
                return -1;
            }
        }
    } else {
        None
    };
    let protocol = if use_tls {
        crate::http::dto::ProtocolType::Https
    } else {
        crate::http::dto::ProtocolType::Http
    };

    let state_mutex = SERVER_STATE.get_or_init(|| Mutex::new(ServerState::new()));
    let mut state = state_mutex.lock().unwrap();
    if state.running.load(Ordering::SeqCst) {
        return 0;
    }
    if let Some(thread) = state.thread.take() {
        let _ = thread.join();
    }

    set_last_error("");
    let running = Arc::new(AtomicBool::new(true));
    let thread_running = running.clone();
    let (stop_tx, stop_rx) = tokio::sync::oneshot::channel();
    let (ready_tx, ready_rx) = std::sync::mpsc::sync_channel(1);
    let (discovery_tx, discovery_rx) = tokio::sync::mpsc::unbounded_channel();
    let device_type = match device_type {
        1 => crate::model::discovery::DeviceType::Desktop,
        2 => crate::model::discovery::DeviceType::Web,
        3 => crate::model::discovery::DeviceType::Headless,
        4 => crate::model::discovery::DeviceType::Server,
        _ => crate::model::discovery::DeviceType::Mobile,
    };

    let thread = std::thread::spawn(move || {
        let runtime = match tokio::runtime::Builder::new_multi_thread()
            .worker_threads(2)
            .enable_all()
            .build()
        {
            Ok(runtime) => runtime,
            Err(error) => {
                set_last_error(format!("failed to create runtime: {error}"));
                thread_running.store(false, Ordering::SeqCst);
                return;
            }
        };

        let info = crate::http::state::ClientInfo {
            alias,
            version: "2.1".to_string(),
            device_model: (!device_model.is_empty()).then_some(device_model),
            device_type: Some(device_type),
            token,
        };

        let discovery_info = info.clone();
        runtime.spawn(async move {
            if let Err(error) =
                crate::discovery::run(port, discovery_info, protocol, discovery_rx).await
            {
                set_last_error(format!(
                    "Nearby discovery unavailable: {error}. Receiving by IP is still available."
                ));
            }
        });

        if let Err(error) = runtime.block_on(crate::http::server::run_with_port_and_ready(
            port, tls_config, info, true, stop_rx, ready_tx,
        )) {
            set_last_error(error.to_string());
        }
        thread_running.store(false, Ordering::SeqCst);
    });

    state.running = running;
    match ready_rx.recv_timeout(std::time::Duration::from_secs(5)) {
        Ok(Ok(())) => {
            state.stop_tx = Some(stop_tx);
            state.discovery_tx = Some(discovery_tx);
            state.thread = Some(thread);
            0
        }
        Ok(Err(error)) => {
            set_last_error(error);
            let _ = thread.join();
            -2
        }
        Err(error) => {
            set_last_error(format!("server startup timed out: {error}"));
            let _ = stop_tx.send(());
            let _ = thread.join();
            -2
        }
    }
}

#[cfg(feature = "http")]
#[no_mangle]
pub extern "C" fn localsendcore_stop_server() {
    receive::reset();
    let Some(state_mutex) = SERVER_STATE.get() else {
        return;
    };

    let (stop_tx, thread) = {
        let mut state = state_mutex.lock().unwrap();
        state.discovery_tx = None;
        (state.stop_tx.take(), state.thread.take())
    };

    if let Some(stop_tx) = stop_tx {
        let _ = stop_tx.send(());
    }
    if let Some(thread) = thread {
        let _ = thread.join();
    }
}

#[cfg(feature = "http")]
#[no_mangle]
pub extern "C" fn localsendcore_is_server_running() -> bool {
    SERVER_STATE
        .get()
        .map(|state| state.lock().unwrap().running.load(Ordering::SeqCst))
        .unwrap_or(false)
}

#[cfg(all(test, feature = "http"))]
mod tests {
    use super::*;
    use std::io::{Read, Write};
    use std::net::{TcpListener, TcpStream};
    use std::sync::{Arc, Mutex};
    use std::time::Duration;

    struct ServerGuard;

    fn ffi_test_lock() -> std::sync::MutexGuard<'static, ()> {
        static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
        let guard = LOCK
            .get_or_init(|| Mutex::new(()))
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner);
        static TLS_DIRECTORY: OnceLock<std::path::PathBuf> = OnceLock::new();
        let directory = TLS_DIRECTORY.get_or_init(|| {
            std::env::temp_dir().join(format!("localsendcore-ffi-tls-{}", uuid::Uuid::new_v4()))
        });
        tls_identity::configure(directory, "Filz FFI Test").unwrap();
        guard
    }

    impl Drop for ServerGuard {
        fn drop(&mut self) {
            localsendcore_stop_server();
        }
    }

    #[test]
    fn ffi_server_handles_registration() {
        let _test_guard = ffi_test_lock();
        let port = {
            let listener = TcpListener::bind(("127.0.0.1", 0)).unwrap();
            listener.local_addr().unwrap().port()
        };
        let alias = CString::new("LiquidSend Test").unwrap();
        let model = CString::new("Test Mac").unwrap();
        let token = CString::new("test-token").unwrap();

        let result = localsendcore_start_server(
            port,
            alias.as_ptr(),
            model.as_ptr(),
            1,
            token.as_ptr(),
            true,
        );
        let error = last_error()
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner)
            .to_string_lossy()
            .into_owned();
        assert_eq!(result, 0, "{error}");
        let _guard = ServerGuard;
        assert!(localsendcore_is_server_running());

        let body = format!(
            r#"{{"alias":"Client","version":"2.1","deviceModel":"Mac","deviceType":"desktop","fingerprint":"client-token","port":{port},"protocol":"http","download":false}}"#
        );
        let (status, response) = post_https(port, "/api/localsend/v2/register", &body);
        assert_eq!(status, 200, "{}", String::from_utf8_lossy(&response));
        let response = String::from_utf8(response).unwrap();
        assert!(response.contains(r#""alias":"LiquidSend Test""#));
        assert!(response.contains(r#""deviceModel":"Test Mac""#));
        assert!(discovery::devices_json().contains(r#""alias":"Client""#));
    }

    #[test]
    fn ffi_receiver_rejects_an_invalid_pin() {
        let _test_guard = ffi_test_lock();
        let port = {
            let listener = TcpListener::bind(("127.0.0.1", 0)).unwrap();
            listener.local_addr().unwrap().port()
        };
        let alias = CString::new("LiquidSend Test").unwrap();
        let model = CString::new("Test Mac").unwrap();
        let token = CString::new("test-token").unwrap();
        let pin = CString::new("123456").unwrap();
        assert_eq!(localsendcore_set_receive_pin(pin.as_ptr()), 0);
        assert_eq!(
            localsendcore_start_server(
                port,
                alias.as_ptr(),
                model.as_ptr(),
                1,
                token.as_ptr(),
                true
            ),
            0
        );
        let _guard = ServerGuard;

        let body = r#"{"info":{"alias":"Sender","version":"2.1","deviceModel":"Mac","deviceType":"desktop","fingerprint":"sender-token","port":53317,"protocol":"http","download":false},"files":{"file-1":{"id":"file-1","fileName":"hello.txt","size":5,"fileType":"text/plain"}}}"#;
        let (status, _) = post_https(port, "/api/localsend/v2/prepare-upload?pin=wrong", body);
        assert_eq!(status, 401);
    }

    #[test]
    fn ffi_sends_file_to_v2_receiver() {
        let _test_guard = ffi_test_lock();
        let listener = TcpListener::bind(("127.0.0.1", 0)).unwrap();
        let port = listener.local_addr().unwrap().port();
        let uploaded = Arc::new(Mutex::new(Vec::new()));
        let uploaded_from_server = uploaded.clone();

        let server = std::thread::spawn(move || {
            for request_index in 0..2 {
                let (mut stream, _) = listener.accept().unwrap();
                let (request_line, body) = read_http_request(&mut stream);
                if request_index == 0 {
                    assert!(request_line.contains("/api/localsend/v2/prepare-upload"));
                    let payload: serde_json::Value = serde_json::from_slice(&body).unwrap();
                    let file_id = payload["files"].as_object().unwrap().keys().next().unwrap();
                    assert_eq!(payload["info"]["fingerprint"], "sender-token");
                    let response = serde_json::json!({
                        "sessionId": "session-1",
                        "files": { file_id: "upload-token" }
                    })
                    .to_string();
                    write_http_response(&mut stream, 200, &response);
                } else {
                    assert!(request_line.contains("/api/localsend/v2/upload"));
                    *uploaded_from_server.lock().unwrap() = body;
                    write_http_response(&mut stream, 200, "");
                }
            }
        });

        let file_path = std::env::temp_dir().join(format!(
            "localsendcore-send-test-{}.txt",
            uuid::Uuid::new_v4()
        ));
        std::fs::write(&file_path, b"hello from LiquidSend").unwrap();

        let target_ip = CString::new("127.0.0.1").unwrap();
        let target_protocol = CString::new("http").unwrap();
        let alias = CString::new("LiquidSend Test").unwrap();
        let model = CString::new("Test Mac").unwrap();
        let token = CString::new("sender-token").unwrap();
        let path = CString::new(file_path.to_string_lossy().as_bytes()).unwrap();
        let name = CString::new("hello.txt").unwrap();
        let mime = CString::new("text/plain").unwrap();

        let result = localsendcore_send_file(
            target_ip.as_ptr(),
            port,
            target_protocol.as_ptr(),
            alias.as_ptr(),
            53317,
            model.as_ptr(),
            1,
            token.as_ptr(),
            path.as_ptr(),
            name.as_ptr(),
            mime.as_ptr(),
        );
        let error = last_error()
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner)
            .to_string_lossy()
            .into_owned();
        assert_eq!(result, 0, "{error}");

        server.join().unwrap();
        assert_eq!(&*uploaded.lock().unwrap(), b"hello from LiquidSend");
        let _ = std::fs::remove_file(file_path);
    }

    #[test]
    fn ffi_sends_text_message_with_preview_without_upload() {
        let _test_guard = ffi_test_lock();
        let listener = TcpListener::bind(("127.0.0.1", 0)).unwrap();
        let port = listener.local_addr().unwrap().port();

        let server = std::thread::spawn(move || {
            let (mut stream, _) = listener.accept().unwrap();
            let (request_line, body) = read_http_request(&mut stream);
            assert!(request_line.contains("/api/localsend/v2/prepare-upload"));
            let payload: serde_json::Value = serde_json::from_slice(&body).unwrap();
            let file = payload["files"]
                .as_object()
                .unwrap()
                .values()
                .next()
                .unwrap();
            assert_eq!(file["fileType"], "text/plain");
            assert_eq!(file["preview"], "hello world");
            write_http_response(&mut stream, 204, "");
        });

        let file_path = std::env::temp_dir().join(format!(
            "localsendcore-text-message-test-{}.txt",
            uuid::Uuid::new_v4()
        ));
        std::fs::write(&file_path, b"hello world").unwrap();

        let target_ip = CString::new("127.0.0.1").unwrap();
        let target_protocol = CString::new("http").unwrap();
        let sender_protocol = CString::new("http").unwrap();
        let target_alias = CString::new("LocalSend Receiver").unwrap();
        let alias = CString::new("LiquidSend Test").unwrap();
        let model = CString::new("Test Mac").unwrap();
        let token = CString::new("sender-token").unwrap();
        let files = CString::new(format!(
            r#"[{{"filePath":"{}","fileName":"message.txt","fileType":"text/plain","preview":"hello world"}}]"#,
            file_path.to_string_lossy()
        ))
        .unwrap();

        let result = localsendcore_send_files_json(
            target_ip.as_ptr(),
            port,
            target_protocol.as_ptr(),
            target_alias.as_ptr(),
            std::ptr::null(),
            alias.as_ptr(),
            53317,
            sender_protocol.as_ptr(),
            model.as_ptr(),
            1,
            token.as_ptr(),
            files.as_ptr(),
        );
        let error = last_error()
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner)
            .to_string_lossy()
            .into_owned();
        assert_eq!(result, 0, "{error}");
        server.join().unwrap();
        let progress = send_progress()
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner)
            .clone();
        assert_eq!(progress.status, "finished");
        assert_eq!(progress.completed_files, 1);
        assert_eq!(progress.sent_bytes, 11);
        let _ = std::fs::remove_file(file_path);
    }

    #[test]
    fn ffi_cancels_send_while_waiting_for_acceptance() {
        let _test_guard = ffi_test_lock();
        let listener = TcpListener::bind(("127.0.0.1", 0)).unwrap();
        let port = listener.local_addr().unwrap().port();
        let (prepared_tx, prepared_rx) = std::sync::mpsc::sync_channel(1);

        let server = std::thread::spawn(move || {
            let (mut prepare_stream, _) = listener.accept().unwrap();
            let (request_line, _) = read_http_request(&mut prepare_stream);
            assert!(request_line.contains("/api/localsend/v2/prepare-upload"));
            prepared_tx.send(()).unwrap();

            let (mut cancel_stream, _) = listener.accept().unwrap();
            let (request_line, _) = read_http_request(&mut cancel_stream);
            assert!(request_line.contains("/api/localsend/v2/cancel"));
            write_http_response(&mut cancel_stream, 200, "");
        });

        let file_path = std::env::temp_dir().join(format!(
            "localsendcore-cancel-test-{}.txt",
            uuid::Uuid::new_v4()
        ));
        std::fs::write(&file_path, b"cancel me").unwrap();
        let send_path = file_path.clone();
        let sender = std::thread::spawn(move || {
            let target_ip = CString::new("127.0.0.1").unwrap();
            let target_protocol = CString::new("http").unwrap();
            let alias = CString::new("LiquidSend Test").unwrap();
            let model = CString::new("Test Mac").unwrap();
            let token = CString::new("sender-token").unwrap();
            let path = CString::new(send_path.to_string_lossy().as_bytes()).unwrap();
            let name = CString::new("cancel.txt").unwrap();
            let mime = CString::new("text/plain").unwrap();
            localsendcore_send_file(
                target_ip.as_ptr(),
                port,
                target_protocol.as_ptr(),
                alias.as_ptr(),
                53317,
                model.as_ptr(),
                1,
                token.as_ptr(),
                path.as_ptr(),
                name.as_ptr(),
                mime.as_ptr(),
            )
        });

        prepared_rx.recv_timeout(Duration::from_secs(2)).unwrap();
        localsendcore_cancel_send();
        assert_ne!(sender.join().unwrap(), 0);
        server.join().unwrap();
        assert_eq!(
            send_progress()
                .lock()
                .unwrap_or_else(std::sync::PoisonError::into_inner)
                .status,
            "canceled"
        );
        let _ = std::fs::remove_file(file_path);
    }

    #[test]
    fn ffi_sends_and_receives_file_over_https() {
        let _test_guard = ffi_test_lock();
        let port = {
            let listener = TcpListener::bind(("127.0.0.1", 0)).unwrap();
            listener.local_addr().unwrap().port()
        };
        let receive_directory = std::env::temp_dir().join(format!(
            "localsendcore-https-receive-test-{}",
            uuid::Uuid::new_v4()
        ));
        receive::set_directory(receive_directory.to_string_lossy().into_owned()).unwrap();
        receive::set_pin(None);
        let alias = CString::new("Filz HTTPS Receiver").unwrap();
        let model = CString::new("Test Mac").unwrap();
        let token = CString::new("https-receiver-token").unwrap();
        assert_eq!(
            localsendcore_start_server(
                port,
                alias.as_ptr(),
                model.as_ptr(),
                1,
                token.as_ptr(),
                true
            ),
            0
        );
        let _guard = ServerGuard;

        let source_path = std::env::temp_dir().join(format!(
            "localsendcore-https-send-test-{}.txt",
            uuid::Uuid::new_v4()
        ));
        std::fs::write(&source_path, b"encrypted transfer").unwrap();
        let sender_path = source_path.clone();
        let sender = std::thread::spawn(move || {
            let target_ip = CString::new("127.0.0.1").unwrap();
            let target_protocol = CString::new("https").unwrap();
            let alias = CString::new("Filz HTTPS Sender").unwrap();
            let model = CString::new("Test Mac").unwrap();
            let token = CString::new("https-sender-token").unwrap();
            let path = CString::new(sender_path.to_string_lossy().as_bytes()).unwrap();
            let name = CString::new("encrypted.txt").unwrap();
            let mime = CString::new("text/plain").unwrap();
            localsendcore_send_file(
                target_ip.as_ptr(),
                port,
                target_protocol.as_ptr(),
                alias.as_ptr(),
                port,
                model.as_ptr(),
                1,
                token.as_ptr(),
                path.as_ptr(),
                name.as_ptr(),
                mime.as_ptr(),
            )
        });

        let deadline = std::time::Instant::now() + Duration::from_secs(3);
        let request_id = loop {
            let pending: serde_json::Value =
                serde_json::from_str(&receive::pending_json()).unwrap();
            if let Some(id) = pending.get("id").and_then(serde_json::Value::as_str) {
                assert_eq!(
                    pending["senderFingerprint"].as_str().map(str::len),
                    Some(64)
                );
                break id.to_string();
            }
            assert!(
                std::time::Instant::now() < deadline,
                "HTTPS receive request timed out"
            );
            std::thread::sleep(Duration::from_millis(20));
        };
        receive::decide(&request_id, true).unwrap();
        let result = sender.join().unwrap();
        let error = last_error()
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner)
            .to_string_lossy()
            .into_owned();
        assert_eq!(result, 0, "{error}");
        assert_eq!(
            std::fs::read(receive_directory.join("encrypted.txt")).unwrap(),
            b"encrypted transfer"
        );
        let _ = std::fs::remove_file(source_path);
        let _ = std::fs::remove_dir_all(receive_directory);
    }

    #[test]
    fn ffi_accepts_v1_transfer_over_https() {
        let _test_guard = ffi_test_lock();
        let port = {
            let listener = TcpListener::bind(("127.0.0.1", 0)).unwrap();
            listener.local_addr().unwrap().port()
        };
        let receive_directory = std::env::temp_dir().join(format!(
            "localsendcore-v1-receive-test-{}",
            uuid::Uuid::new_v4()
        ));
        receive::set_directory(receive_directory.to_string_lossy().into_owned()).unwrap();
        receive::set_pin(Some("123456".to_string()));
        let alias = CString::new("Filz V1 Receiver").unwrap();
        let model = CString::new("iPhone").unwrap();
        let token = CString::new("v1-receiver-token").unwrap();
        assert_eq!(
            localsendcore_start_server(
                port,
                alias.as_ptr(),
                model.as_ptr(),
                0,
                token.as_ptr(),
                true
            ),
            0
        );
        let _guard = ServerGuard;

        let sender = std::thread::spawn(move || {
            let (status, info) = get_https(port, "/api/localsend/v1/info");
            assert_eq!(status, 200, "{}", String::from_utf8_lossy(&info));
            let info: serde_json::Value = serde_json::from_slice(&info).unwrap();
            assert_eq!(info["alias"], "Filz V1 Receiver");

            let request = r#"{
                "info": {
                    "alias": "Legacy LocalSend",
                    "deviceModel": "Desktop",
                    "deviceType": "desktop"
                },
                "files": {
                    "legacy-file": {
                        "id": "legacy-file",
                        "fileName": "legacy.txt",
                        "size": 16,
                        "fileType": "text"
                    }
                }
            }"#;
            let (status, response) =
                post_https(port, "/api/localsend/v1/send-request?pin=123456", request);
            assert_eq!(status, 200, "{}", String::from_utf8_lossy(&response));
            let tokens: std::collections::HashMap<String, String> =
                serde_json::from_slice(&response).unwrap();
            let path = format!(
                "/api/localsend/v1/send?fileId=legacy-file&token={}",
                tokens.get("legacy-file").unwrap()
            );
            let (status, response) =
                post_https_bytes(port, &path, b"legacy transfer!", "application/octet-stream");
            assert_eq!(status, 200, "{}", String::from_utf8_lossy(&response));
        });

        let deadline = std::time::Instant::now() + Duration::from_secs(3);
        let request_id = loop {
            if let Some(id) = serde_json::from_str::<serde_json::Value>(&receive::pending_json())
                .unwrap()
                .get("id")
                .and_then(serde_json::Value::as_str)
            {
                break id.to_string();
            }
            assert!(
                std::time::Instant::now() < deadline,
                "v1 receive request timed out"
            );
            std::thread::sleep(Duration::from_millis(20));
        };
        receive::decide(&request_id, true).unwrap();
        assert_eq!(receive::pending_json(), "null");
        sender.join().unwrap();
        assert_eq!(
            std::fs::read(receive_directory.join("legacy.txt")).unwrap(),
            b"legacy transfer!"
        );
        let _ = std::fs::remove_dir_all(receive_directory);
    }

    #[test]
    fn ffi_receives_text_message_without_user_acceptance() {
        let _test_guard = ffi_test_lock();
        let port = {
            let listener = TcpListener::bind(("127.0.0.1", 0)).unwrap();
            listener.local_addr().unwrap().port()
        };
        receive::set_pin(None);
        let alias = CString::new("Filz Text Receiver").unwrap();
        let model = CString::new("iPhone").unwrap();
        let token = CString::new("text-receiver-token").unwrap();
        assert_eq!(
            localsendcore_start_server(
                port,
                alias.as_ptr(),
                model.as_ptr(),
                0,
                token.as_ptr(),
                true
            ),
            0
        );
        let _guard = ServerGuard;

        let sender = std::thread::spawn(move || {
            let body = r#"{"info":{"alias":"LocalSend Sender","version":"2.1","deviceModel":"Mac","deviceType":"desktop","fingerprint":"sender-token","port":53317,"protocol":"https","download":false},"files":{"message-file":{"id":"message-file","fileName":"message-file.txt","size":11,"fileType":"text/plain","preview":"hello world"}}}"#;
            let (status, response) = post_https(port, "/api/localsend/v2/prepare-upload", body);
            assert_eq!(status, 204, "{}", String::from_utf8_lossy(&response));
        });
        sender.join().unwrap();
        assert_eq!(receive::pending_json(), "null");
        let progress: serde_json::Value = serde_json::from_str(&receive::progress_json()).unwrap();
        assert_eq!(progress["status"], "finished");
        assert_eq!(progress["textMessage"], "hello world");
        assert_eq!(progress["completedFiles"], 1);
    }

    #[test]
    fn ffi_receives_file_after_user_accepts() {
        let _test_guard = ffi_test_lock();
        let port = {
            let listener = TcpListener::bind(("127.0.0.1", 0)).unwrap();
            listener.local_addr().unwrap().port()
        };
        let receive_directory = std::env::temp_dir().join(format!(
            "localsendcore-receive-test-{}",
            uuid::Uuid::new_v4()
        ));
        receive::set_directory(receive_directory.to_string_lossy().into_owned()).unwrap();
        let alias = CString::new("LiquidSend Test").unwrap();
        let model = CString::new("Test Mac").unwrap();
        let token = CString::new("test-token").unwrap();
        assert_eq!(
            localsendcore_start_server(
                port,
                alias.as_ptr(),
                model.as_ptr(),
                1,
                token.as_ptr(),
                true
            ),
            0
        );
        let _guard = ServerGuard;

        let sender = std::thread::spawn(move || {
            let body = r#"{"info":{"alias":"Sender","version":"2.1","deviceModel":"Mac","deviceType":"desktop","fingerprint":"sender-token","port":53317,"protocol":"http","download":false},"files":{"file-1":{"id":"file-1","fileName":"hello.txt","size":14,"fileType":"text/plain"}}}"#;
            let (status, response) = post_https(port, "/api/localsend/v2/prepare-upload", body);
            assert_eq!(status, 200, "{}", String::from_utf8_lossy(&response));
            let prepared: crate::http::dto::PrepareUploadResponseDto =
                serde_json::from_slice(&response).unwrap();
            let upload_token = prepared.files.get("file-1").unwrap();
            let upload_body = b"hello receiver";
            let path = format!(
                "/api/localsend/v2/upload?sessionId={}&fileId=file-1&token={}",
                prepared.session_id, upload_token
            );
            let (status, response) = post_https_bytes(port, &path, upload_body, "text/plain");
            assert_eq!(status, 200, "{}", String::from_utf8_lossy(&response));
        });

        let deadline = std::time::Instant::now() + Duration::from_secs(3);
        let request_id = loop {
            if let Some(id) = serde_json::from_str::<serde_json::Value>(&receive::pending_json())
                .unwrap()
                .get("id")
                .and_then(serde_json::Value::as_str)
            {
                break id.to_string();
            }
            assert!(
                std::time::Instant::now() < deadline,
                "receive request timed out"
            );
            std::thread::sleep(Duration::from_millis(20));
        };
        receive::decide(&request_id, true).unwrap();
        sender.join().unwrap();
        assert_eq!(
            std::fs::read(receive_directory.join("hello.txt")).unwrap(),
            b"hello receiver"
        );
        let progress: serde_json::Value = serde_json::from_str(&receive::progress_json()).unwrap();
        assert_eq!(progress["status"], "finished");
        let _ = std::fs::remove_dir_all(receive_directory);
    }

    fn read_http_request(stream: &mut TcpStream) -> (String, Vec<u8>) {
        stream
            .set_read_timeout(Some(Duration::from_secs(5)))
            .unwrap();
        let mut received = Vec::new();
        let mut buffer = [0_u8; 4096];
        let header_end = loop {
            let length = stream.read(&mut buffer).unwrap();
            assert!(length > 0);
            received.extend_from_slice(&buffer[..length]);
            if let Some(index) = received.windows(4).position(|part| part == b"\r\n\r\n") {
                break index + 4;
            }
        };
        let header = String::from_utf8(received[..header_end].to_vec()).unwrap();
        let content_length = header
            .lines()
            .find_map(|line| {
                line.to_ascii_lowercase()
                    .strip_prefix("content-length: ")
                    .and_then(|value| value.parse::<usize>().ok())
            })
            .unwrap_or(0);
        while received.len() - header_end < content_length {
            let length = stream.read(&mut buffer).unwrap();
            assert!(length > 0);
            received.extend_from_slice(&buffer[..length]);
        }
        (
            header.lines().next().unwrap().to_string(),
            received[header_end..header_end + content_length].to_vec(),
        )
    }

    fn post_https(port: u16, path: &str, body: &str) -> (u16, Vec<u8>) {
        post_https_bytes(port, path, body.as_bytes(), "application/json")
    }

    fn get_https(port: u16, path: &str) -> (u16, Vec<u8>) {
        let identity = tls_identity::current().unwrap();
        let identity_pem = [
            identity.cert.as_bytes(),
            b"\n",
            identity.private_key.as_bytes(),
        ]
        .concat();
        let client = reqwest::Client::builder()
            .use_rustls_tls()
            .danger_accept_invalid_certs(true)
            .identity(reqwest::Identity::from_pem(&identity_pem).unwrap())
            .build()
            .unwrap();
        let runtime = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .unwrap();
        runtime.block_on(async {
            let response = client
                .get(format!("https://127.0.0.1:{port}{path}"))
                .send()
                .await
                .unwrap();
            let status = response.status().as_u16();
            let body = response.bytes().await.unwrap().to_vec();
            (status, body)
        })
    }

    fn post_https_bytes(port: u16, path: &str, body: &[u8], content_type: &str) -> (u16, Vec<u8>) {
        let identity = tls_identity::current().unwrap();
        let identity_pem = [
            identity.cert.as_bytes(),
            b"\n",
            identity.private_key.as_bytes(),
        ]
        .concat();
        let client = reqwest::Client::builder()
            .use_rustls_tls()
            .danger_accept_invalid_certs(true)
            .identity(reqwest::Identity::from_pem(&identity_pem).unwrap())
            .build()
            .unwrap();
        let runtime = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .unwrap();
        runtime.block_on(async {
            let response = client
                .post(format!("https://127.0.0.1:{port}{path}"))
                .header(reqwest::header::CONTENT_TYPE, content_type)
                .body(body.to_vec())
                .send()
                .await
                .unwrap();
            let status = response.status().as_u16();
            let body = response.bytes().await.unwrap().to_vec();
            (status, body)
        })
    }

    fn write_http_response(stream: &mut TcpStream, status: u16, body: &str) {
        let reason = if status == 200 { "OK" } else { "Error" };
        write!(
            stream,
            "HTTP/1.1 {status} {reason}\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",
            body.len()
        )
        .unwrap();
        stream.flush().unwrap();
    }
}
