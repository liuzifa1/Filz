#[cfg(feature = "http")]
use futures_util::StreamExt;
#[cfg(feature = "http")]
use serde::{Deserialize, Serialize};
use std::ffi::{c_char, CStr, CString};
#[cfg(feature = "http")]
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Mutex, OnceLock};
#[cfg(feature = "http")]
use std::sync::Arc;
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
}

#[cfg(feature = "http")]
#[derive(Clone, Default, Serialize)]
#[serde(rename_all = "camelCase")]
struct SendProgress {
    status: String,
    target_alias: String,
    current_file: Option<String>,
    sent_bytes: u64,
    total_bytes: u64,
    completed_files: usize,
    total_files: usize,
    error: Option<String>,
}

#[cfg(feature = "http")]
static SEND_PROGRESS: OnceLock<Mutex<SendProgress>> = OnceLock::new();

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
            protocol,
            sender_alias,
            sender_port,
            sender_device_model,
            device_type,
            sender_token,
            "LocalSend device".to_string(),
            vec![SendFileInput {
                file_path,
                file_name,
                file_type,
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
    sender_alias: *const c_char,
    sender_port: u16,
    sender_device_model: *const c_char,
    sender_device_type: u8,
    sender_token: *const c_char,
    files_json: *const c_char,
) -> i32 {
    let result = (|| -> Result<(), String> {
        let target_ip = read_c_string(target_ip, "target IP")?;
        let target_protocol = read_c_string(target_protocol, "target protocol")?;
        let target_alias = read_c_string(target_alias, "target alias")?;
        let sender_alias = read_c_string(sender_alias, "sender alias")?;
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
            sender_device_model,
            device_type,
            sender_token,
            target_alias,
            files,
        )
    })();
    match result {
        Ok(()) => {
            set_last_error("");
            0
        }
        Err(error) => {
            update_send_progress(|progress| {
                progress.status = "failed".to_string();
                progress.error = Some(error.clone());
            });
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
    sender_device_model: String,
    sender_device_type: crate::model::discovery::DeviceType,
    sender_token: String,
    target_alias: String,
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
            sender_device_model,
            sender_device_type,
            sender_token,
            target_alias,
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
    sender_device_model: String,
    sender_device_type: crate::model::discovery::DeviceType,
    sender_token: String,
    target_alias: String,
    files: Vec<SendFileInput>,
) -> anyhow::Result<()> {
    let _ = rustls::crypto::ring::default_provider().install_default();
    let client = reqwest::Client::builder()
        .use_rustls_tls()
        .danger_accept_invalid_certs(true)
        .connect_timeout(std::time::Duration::from_secs(5))
        .timeout(std::time::Duration::from_secs(300))
        .build()?;
    let mut prepared_files = Vec::new();
    for input in files {
        let metadata = tokio::fs::metadata(&input.file_path).await?;
        if !metadata.is_file() {
            return Err(anyhow::anyhow!("{} is not a file", input.file_name));
        }
        prepared_files.push((uuid::Uuid::new_v4().to_string(), input, metadata.len()));
    }
    let total_bytes = prepared_files.iter().map(|(_, _, size)| size).sum();
    update_send_progress(|progress| {
        *progress = SendProgress {
            status: "waiting".to_string(),
            target_alias,
            total_bytes,
            total_files: prepared_files.len(),
            ..SendProgress::default()
        };
    });
    let info = crate::http::dto::RegisterDto {
        alias: sender_alias,
        version: "2.1".to_string(),
        device_model: (!sender_device_model.is_empty()).then_some(sender_device_model),
        device_type: Some(sender_device_type),
        token: sender_token,
        port: sender_port,
        protocol: crate::http::dto::ProtocolType::Http,
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
                        preview: None,
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
    let response = client
        .post(format!("{base_url}/prepare-upload"))
        .json(&request)
        .send()
        .await?;

    if response.status() == reqwest::StatusCode::NO_CONTENT {
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
        let response = client
            .post(format!("{base_url}/upload"))
            .query(&[
                ("sessionId", prepared.session_id.clone()),
                ("fileId", file_id),
                ("token", file_token),
            ])
            .header(reqwest::header::CONTENT_LENGTH, file_size)
            .header(reqwest::header::CONTENT_TYPE, input.file_type)
            .body(reqwest::Body::wrap_stream(stream))
            .send()
            .await?;
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

        runtime.spawn(crate::discovery::run(port, info.clone(), discovery_rx));

        if let Err(error) = runtime.block_on(crate::http::server::run_with_port_and_ready(
            port, None, info, true, stop_rx, ready_tx,
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
        LOCK.get_or_init(|| Mutex::new(()))
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner)
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

        let result =
            localsendcore_start_server(port, alias.as_ptr(), model.as_ptr(), 1, token.as_ptr());
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
        let request = format!(
            "POST /api/localsend/v2/register HTTP/1.1\r\nHost: 127.0.0.1:{port}\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",
            body.len()
        );
        let mut stream = TcpStream::connect(("127.0.0.1", port)).unwrap();
        stream
            .set_read_timeout(Some(Duration::from_secs(2)))
            .unwrap();
        stream.write_all(request.as_bytes()).unwrap();

        let mut response = String::new();
        stream.read_to_string(&mut response).unwrap();
        assert!(response.starts_with("HTTP/1.1 200 OK"), "{response}");
        assert!(response.contains(r#""alias":"LiquidSend Test""#));
        assert!(response.contains(r#""deviceModel":"Test Mac""#));
        assert!(discovery::devices_json().contains(r#""alias":"Client""#));
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
            localsendcore_start_server(port, alias.as_ptr(), model.as_ptr(), 1, token.as_ptr()),
            0
        );
        let _guard = ServerGuard;

        let sender = std::thread::spawn(move || {
            let body = r#"{"info":{"alias":"Sender","version":"2.1","deviceModel":"Mac","deviceType":"desktop","fingerprint":"sender-token","port":53317,"protocol":"http","download":false},"files":{"file-1":{"id":"file-1","fileName":"hello.txt","size":14,"fileType":"text/plain"}}}"#;
            let request = format!(
                "POST /api/localsend/v2/prepare-upload HTTP/1.1\r\nHost: 127.0.0.1:{port}\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",
                body.len()
            );
            let mut stream = TcpStream::connect(("127.0.0.1", port)).unwrap();
            stream.write_all(request.as_bytes()).unwrap();
            let response = read_http_response(&mut stream);
            assert!(response.0.starts_with("HTTP/1.1 200 OK"), "{}", response.0);
            let prepared: crate::http::dto::PrepareUploadResponseDto =
                serde_json::from_slice(&response.1).unwrap();
            let upload_token = prepared.files.get("file-1").unwrap();
            let upload_body = b"hello receiver";
            let upload_request = format!(
                "POST /api/localsend/v2/upload?sessionId={}&fileId=file-1&token={} HTTP/1.1\r\nHost: 127.0.0.1:{port}\r\nContent-Type: text/plain\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",
                prepared.session_id,
                upload_token,
                upload_body.len()
            );
            let mut stream = TcpStream::connect(("127.0.0.1", port)).unwrap();
            stream.write_all(upload_request.as_bytes()).unwrap();
            stream.write_all(upload_body).unwrap();
            let response = read_http_response(&mut stream);
            assert!(response.0.starts_with("HTTP/1.1 200 OK"), "{}", response.0);
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

    fn read_http_response(stream: &mut TcpStream) -> (String, Vec<u8>) {
        stream
            .set_read_timeout(Some(Duration::from_secs(5)))
            .unwrap();
        let mut response = Vec::new();
        stream.read_to_end(&mut response).unwrap();
        let header_end = response
            .windows(4)
            .position(|part| part == b"\r\n\r\n")
            .map(|index| index + 4)
            .unwrap();
        (
            String::from_utf8(response[..header_end].to_vec()).unwrap(),
            response[header_end..].to_vec(),
        )
    }
}
