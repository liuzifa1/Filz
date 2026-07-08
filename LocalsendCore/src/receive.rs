use crate::http::dto::{ErrorResponse, PrepareUploadRequestDto, PrepareUploadResponseDto};
use crate::model::transfer::FileDto;
use bytes::Bytes;
use http_body_util::{BodyExt, Full};
use hyper::body::Incoming;
use hyper::{Response, StatusCode};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::io::ErrorKind;
use std::net::IpAddr;
use std::path::{Path, PathBuf};
use std::sync::{Mutex, OnceLock};
use tokio::io::AsyncWriteExt;
use tokio::sync::oneshot;

#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct IncomingFile {
    pub id: String,
    pub file_name: String,
    pub size: u64,
    pub file_type: String,
    pub preview: Option<String>,
}

#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct IncomingRequest {
    pub id: String,
    pub sender_alias: String,
    pub sender_ip: String,
    pub sender_port: u16,
    pub sender_protocol: String,
    pub sender_token: String,
    pub sender_fingerprint: String,
    pub files: Vec<IncomingFile>,
    pub total_bytes: u64,
}

#[derive(Clone, Default, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ReceiveProgress {
    pub request_id: Option<String>,
    pub status: String,
    pub started_at_millis: Option<u64>,
    pub sender_alias: String,
    pub sender_ip: Option<String>,
    pub sender_port: Option<u16>,
    pub sender_protocol: Option<String>,
    pub sender_fingerprint: Option<String>,
    pub current_file: Option<String>,
    pub received_bytes: u64,
    pub total_bytes: u64,
    pub completed_files: usize,
    pub total_files: usize,
    pub saved_paths: Vec<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub text_message: Option<String>,
    pub error: Option<String>,
}

struct PendingRequest {
    public: IncomingRequest,
    payload: PrepareUploadRequestDto,
    sender_ip: IpAddr,
    decision: Option<oneshot::Sender<bool>>,
}

#[derive(Clone)]
struct ActiveFile {
    file: FileDto,
    token: String,
    received: u64,
    receiving: bool,
    finished: bool,
    path: Option<PathBuf>,
}

#[derive(Clone)]
struct ActiveSession {
    id: String,
    sender_ip: IpAddr,
    files: HashMap<String, ActiveFile>,
}

struct ReceiveManager {
    directory: PathBuf,
    pin: Option<String>,
    pending: Option<PendingRequest>,
    active: Option<ActiveSession>,
    progress: ReceiveProgress,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct V1SenderInfo {
    alias: String,
    device_model: Option<String>,
    device_type: Option<crate::model::discovery::DeviceType>,
}

#[derive(Deserialize)]
struct V1PrepareUploadRequest {
    info: V1SenderInfo,
    files: HashMap<String, FileDto>,
}

impl Default for ReceiveManager {
    fn default() -> Self {
        Self {
            directory: std::env::temp_dir().join("LiquidSend Received Files"),
            pin: None,
            pending: None,
            active: None,
            progress: ReceiveProgress::default(),
        }
    }
}

static RECEIVE_MANAGER: OnceLock<Mutex<ReceiveManager>> = OnceLock::new();

fn manager() -> &'static Mutex<ReceiveManager> {
    RECEIVE_MANAGER.get_or_init(|| Mutex::new(ReceiveManager::default()))
}

fn lock_manager() -> std::sync::MutexGuard<'static, ReceiveManager> {
    manager()
        .lock()
        .unwrap_or_else(std::sync::PoisonError::into_inner)
}

fn unix_time_millis() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|duration| duration.as_millis() as u64)
        .unwrap_or(0)
}

pub fn set_directory(path: String) -> Result<(), String> {
    let path = PathBuf::from(path);
    std::fs::create_dir_all(&path).map_err(|error| error.to_string())?;
    lock_manager().directory = path;
    Ok(())
}

pub fn set_pin(pin: Option<String>) {
    lock_manager().pin = pin.filter(|value| !value.is_empty());
}

pub fn pending_json() -> String {
    serde_json::to_string(
        &lock_manager()
            .pending
            .as_ref()
            .filter(|pending| pending.decision.is_some())
            .map(|pending| &pending.public),
    )
    .unwrap_or_else(|_| "null".to_string())
}

pub fn progress_json() -> String {
    serde_json::to_string(&lock_manager().progress).unwrap_or_else(|_| "{}".to_string())
}

pub fn reset() {
    let mut state = lock_manager();
    if let Some(sender) = state
        .pending
        .as_mut()
        .and_then(|pending| pending.decision.take())
    {
        let _ = sender.send(false);
    }
    state.pending = None;
    state.active = None;
    state.pin = None;
}

pub fn cancel_current() {
    let mut state = lock_manager();
    if let Some(sender) = state
        .pending
        .as_mut()
        .and_then(|pending| pending.decision.take())
    {
        let _ = sender.send(false);
    }
    state.pending = None;
    state.active = None;
    state.progress.status = "canceled".to_string();
    state.progress.current_file = None;
    state.progress.error = None;
}

pub fn decide(request_id: &str, accepted: bool) -> Result<(), String> {
    let sender = {
        let mut state = lock_manager();
        let pending = state
            .pending
            .as_mut()
            .ok_or_else(|| "There is no pending receive request".to_string())?;
        if pending.public.id != request_id {
            return Err("The receive request is no longer active".to_string());
        }
        let sender = pending
            .decision
            .take()
            .ok_or_else(|| "The receive request was already answered".to_string())?;
        state.progress.status = if accepted { "approved" } else { "declined" }.to_string();
        sender
    };
    sender
        .send(accepted)
        .map_err(|_| "The sender disconnected before the decision was delivered".to_string())
}

pub async fn prepare_upload(
    body: Incoming,
    sender_ip: IpAddr,
    request_pin: Option<&str>,
    sender_fingerprint: Option<String>,
) -> Response<Full<Bytes>> {
    let payload = match body.collect().await {
        Ok(body) => match serde_json::from_slice::<PrepareUploadRequestDto>(&body.to_bytes()) {
            Ok(payload) => payload,
            Err(_) => return error_response(StatusCode::BAD_REQUEST, "Request body malformed"),
        },
        Err(_) => return error_response(StatusCode::BAD_REQUEST, "Could not read request body"),
    };
    prepare_payload(payload, sender_ip, request_pin, sender_fingerprint, false).await
}

pub async fn prepare_upload_v1(
    body: Incoming,
    sender_ip: IpAddr,
    request_pin: Option<&str>,
    sender_fingerprint: String,
) -> Response<Full<Bytes>> {
    let payload = match body.collect().await {
        Ok(body) => match serde_json::from_slice::<V1PrepareUploadRequest>(&body.to_bytes()) {
            Ok(payload) => payload,
            Err(_) => return error_response(StatusCode::BAD_REQUEST, "Request body malformed"),
        },
        Err(_) => return error_response(StatusCode::BAD_REQUEST, "Could not read request body"),
    };
    let payload = PrepareUploadRequestDto {
        info: crate::http::dto::RegisterDto {
            alias: payload.info.alias,
            version: "1.0".to_string(),
            device_model: payload.info.device_model,
            device_type: payload.info.device_type,
            token: sender_fingerprint.clone(),
            port: 0,
            protocol: crate::http::dto::ProtocolType::Https,
            has_web_interface: false,
        },
        files: payload.files,
    };
    prepare_payload(
        payload,
        sender_ip,
        request_pin,
        Some(sender_fingerprint),
        true,
    )
    .await
}

async fn prepare_payload(
    payload: PrepareUploadRequestDto,
    sender_ip: IpAddr,
    request_pin: Option<&str>,
    sender_fingerprint: Option<String>,
    v1_response: bool,
) -> Response<Full<Bytes>> {
    if let Some(expected_pin) = lock_manager().pin.clone() {
        if request_pin != Some(expected_pin.as_str()) {
            return error_response(StatusCode::UNAUTHORIZED, "Invalid PIN");
        }
    }
    if payload.files.is_empty() {
        return error_response(
            StatusCode::BAD_REQUEST,
            "Request must contain at least one file",
        );
    }

    let request_id = uuid::Uuid::new_v4().to_string();
    let sender_token = payload.info.token.clone();
    let sender_fingerprint = sender_fingerprint
        .filter(|fingerprint| !fingerprint.is_empty())
        .unwrap_or_else(|| sender_token.clone());
    let total_bytes = payload.files.values().map(|file| file.size).sum();
    let text_message = text_message(&payload.files);
    if let Some(message) = text_message {
        let mut state = lock_manager();
        if state.pending.is_some() || state.active.is_some() {
            return error_response(StatusCode::CONFLICT, "Blocked by another session");
        }
        state.progress = ReceiveProgress {
            request_id: Some(request_id),
            status: "finished".to_string(),
            started_at_millis: Some(unix_time_millis()),
            sender_alias: payload.info.alias,
            sender_ip: Some(sender_ip.to_string()),
            sender_port: (payload.info.port != 0).then_some(payload.info.port),
            sender_protocol: Some(payload.info.protocol.as_str().to_string()),
            sender_fingerprint: Some(sender_fingerprint),
            received_bytes: total_bytes,
            total_bytes,
            completed_files: payload.files.len(),
            total_files: payload.files.len(),
            text_message: Some(message),
            ..ReceiveProgress::default()
        };
        return empty_response(StatusCode::NO_CONTENT);
    }
    let public = IncomingRequest {
        id: request_id.clone(),
        sender_alias: payload.info.alias.clone(),
        sender_ip: sender_ip.to_string(),
        sender_port: payload.info.port,
        sender_protocol: payload.info.protocol.as_str().to_string(),
        sender_token,
        sender_fingerprint: sender_fingerprint.clone(),
        files: payload
            .files
            .values()
            .map(|file| IncomingFile {
                id: file.id.clone(),
                file_name: file.file_name.clone(),
                size: file.size,
                file_type: file.file_type.clone(),
                preview: file.preview.clone(),
            })
            .collect(),
        total_bytes,
    };
    let (decision_tx, decision_rx) = oneshot::channel();
    {
        let mut state = lock_manager();
        if state.pending.is_some() || state.active.is_some() {
            return error_response(StatusCode::CONFLICT, "Blocked by another session");
        }
        state.progress = ReceiveProgress {
            request_id: Some(request_id.clone()),
            status: "waiting".to_string(),
            started_at_millis: Some(unix_time_millis()),
            sender_alias: payload.info.alias.clone(),
            sender_ip: Some(sender_ip.to_string()),
            sender_port: (payload.info.port != 0).then_some(payload.info.port),
            sender_protocol: Some(payload.info.protocol.as_str().to_string()),
            sender_fingerprint: Some(sender_fingerprint),
            total_bytes,
            total_files: payload.files.len(),
            ..ReceiveProgress::default()
        };
        state.pending = Some(PendingRequest {
            public,
            payload,
            sender_ip,
            decision: Some(decision_tx),
        });
    }

    let accepted = tokio::time::timeout(std::time::Duration::from_secs(300), decision_rx)
        .await
        .ok()
        .and_then(Result::ok)
        .unwrap_or(false);
    let pending = {
        let mut state = lock_manager();
        state.pending.take()
    };
    let Some(pending) = pending else {
        return error_response(StatusCode::CONFLICT, "Receive request was canceled");
    };
    if !accepted {
        let mut state = lock_manager();
        state.progress.status = "declined".to_string();
        return error_response(StatusCode::FORBIDDEN, "File request declined by recipient");
    }

    let session_id = uuid::Uuid::new_v4().to_string();
    let mut response_files = HashMap::new();
    let mut active_files = HashMap::new();
    for (id, file) in pending.payload.files {
        let token = uuid::Uuid::new_v4().to_string();
        response_files.insert(id.clone(), token.clone());
        active_files.insert(
            id,
            ActiveFile {
                file,
                token,
                received: 0,
                receiving: false,
                finished: false,
                path: None,
            },
        );
    }
    {
        let mut state = lock_manager();
        state.progress.status = "receiving".to_string();
        state.active = Some(ActiveSession {
            id: session_id.clone(),
            sender_ip: pending.sender_ip,
            files: active_files,
        });
    }
    if v1_response {
        json_response(StatusCode::OK, &response_files)
    } else {
        json_response(
            StatusCode::OK,
            &PrepareUploadResponseDto {
                session_id,
                files: response_files,
            },
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn accepts_legacy_prepare_info() {
        let payload = br#"{
            "info": {"alias": "Legacy sender"},
            "files": {
                "file-1": {
                    "id": "file-1",
                    "fileName": "hello.txt",
                    "size": 5,
                    "fileType": "text/plain"
                }
            }
        }"#;

        let request: PrepareUploadRequestDto = serde_json::from_slice(payload).unwrap();
        assert_eq!(request.info.alias, "Legacy sender");
        assert_eq!(request.info.protocol, crate::http::dto::ProtocolType::Http);
    }
}

pub async fn upload(
    body: Incoming,
    sender_ip: IpAddr,
    session_id: &str,
    file_id: &str,
    token: &str,
) -> Response<Full<Bytes>> {
    upload_inner(body, sender_ip, Some(session_id), file_id, token).await
}

pub async fn upload_v1(
    body: Incoming,
    sender_ip: IpAddr,
    file_id: &str,
    token: &str,
) -> Response<Full<Bytes>> {
    upload_inner(body, sender_ip, None, file_id, token).await
}

async fn upload_inner(
    mut body: Incoming,
    sender_ip: IpAddr,
    session_id: Option<&str>,
    file_id: &str,
    token: &str,
) -> Response<Full<Bytes>> {
    let (directory, file_name, expected_size) = {
        let mut state = lock_manager();
        let directory = state.directory.clone();
        let Some(session) = state.active.as_mut() else {
            return error_response(StatusCode::CONFLICT, "No session");
        };
        if session.sender_ip != sender_ip
            || session_id.is_some_and(|session_id| session.id != session_id)
        {
            return error_response(StatusCode::FORBIDDEN, "Invalid session");
        }
        let Some(file) = session.files.get_mut(file_id) else {
            return error_response(StatusCode::FORBIDDEN, "Invalid file id");
        };
        if file.token != token || file.finished || file.receiving {
            return error_response(StatusCode::FORBIDDEN, "Invalid token");
        }
        file.receiving = true;
        (
            directory,
            safe_file_name(&file.file.file_name),
            file.file.size,
        )
    };

    if let Err(error) = tokio::fs::create_dir_all(&directory).await {
        return finish_with_error(format!("Could not create receive directory: {error}"));
    }
    let (destination, mut output) = match create_unique_file(&directory, &file_name).await {
        Ok(file) => file,
        Err(error) => return finish_with_error(format!("Could not create received file: {error}")),
    };

    while let Some(frame) = body.frame().await {
        let frame = match frame {
            Ok(frame) => frame,
            Err(error) => {
                return finish_upload_with_error(
                    &destination,
                    format!("Upload interrupted: {error}"),
                )
                .await
            }
        };
        if let Some(data) = frame.data_ref() {
            if let Err(error) = output.write_all(data).await {
                return finish_upload_with_error(
                    &destination,
                    format!("Could not save received file: {error}"),
                )
                .await;
            }
            let mut state = lock_manager();
            if let Some(session) = state.active.as_mut() {
                if let Some(file) = session.files.get_mut(file_id) {
                    file.received += data.len() as u64;
                }
                state.progress.received_bytes += data.len() as u64;
                state.progress.current_file = Some(file_name.clone());
            }
        }
    }
    if let Err(error) = output.flush().await {
        return finish_upload_with_error(
            &destination,
            format!("Could not finish received file: {error}"),
        )
        .await;
    }

    enum UploadFinalization {
        Finished,
        Failed(String),
        Canceled,
        InvalidFileId,
    }

    let finalization = {
        let mut state = lock_manager();

        if state.active.is_none() {
            UploadFinalization::Canceled
        } else {
            let file_result = {
                let session = state.active.as_mut().expect("active session checked");
                match session.files.get_mut(file_id) {
                    Some(file) => {
                        let actual_size = file.received;
                        if actual_size == expected_size {
                            file.finished = true;
                            file.path = Some(destination.clone());
                        }
                        Some((
                            actual_size,
                            session.files.values().all(|file| file.finished),
                        ))
                    }
                    None => None,
                }
            };

            match file_result {
                Some((actual_size, all_finished)) if actual_size != expected_size => {
                    let message =
                        format!("Expected {expected_size} bytes but received {actual_size}");
                    state.progress.status = "failed".to_string();
                    state.progress.error = Some(message.clone());
                    state.active = None;
                    UploadFinalization::Failed(message)
                }
                Some((_, all_finished)) => {
                    state.progress.completed_files += 1;
                    state
                        .progress
                        .saved_paths
                        .push(destination.to_string_lossy().into_owned());
                    if all_finished {
                        state.progress.status = "finished".to_string();
                        state.progress.current_file = None;
                        state.active = None;
                    }
                    UploadFinalization::Finished
                }
                None => UploadFinalization::InvalidFileId,
            }
        }
    };

    match finalization {
        UploadFinalization::Finished => empty_response(StatusCode::OK),
        UploadFinalization::Failed(message) => {
            let _ = tokio::fs::remove_file(&destination).await;
            error_response(StatusCode::INTERNAL_SERVER_ERROR, &message)
        }
        UploadFinalization::Canceled => {
            let _ = tokio::fs::remove_file(&destination).await;
            error_response(StatusCode::CONFLICT, "Session was canceled")
        }
        UploadFinalization::InvalidFileId => {
            let _ = tokio::fs::remove_file(&destination).await;
            error_response(StatusCode::FORBIDDEN, "Invalid file id")
        }
    }
}

pub fn cancel(sender_ip: IpAddr, session_id: Option<&str>) -> Response<Full<Bytes>> {
    let mut state = lock_manager();
    if let Some(pending) = state.pending.as_ref() {
        if pending.sender_ip == sender_ip {
            if let Some(mut pending) = state.pending.take() {
                let sender = pending.decision.take();
                state.progress.status = "canceled".to_string();
                if let Some(sender) = sender {
                    let _ = sender.send(false);
                }
            } else {
                state.progress.status = "canceled".to_string();
            }
            return empty_response(StatusCode::OK);
        }
    }
    if let Some(active) = state.active.as_ref() {
        if active.sender_ip == sender_ip
            && session_id.is_none_or(|session_id| session_id == active.id)
        {
            state.active = None;
            state.progress.status = "canceled".to_string();
            return empty_response(StatusCode::OK);
        }
    }
    error_response(StatusCode::FORBIDDEN, "No permission")
}

async fn create_unique_file(
    directory: &Path,
    file_name: &str,
) -> std::io::Result<(PathBuf, tokio::fs::File)> {
    let initial = directory.join(file_name);
    match tokio::fs::OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(&initial)
        .await
    {
        Ok(file) => return Ok((initial, file)),
        Err(error) if error.kind() == ErrorKind::AlreadyExists => {}
        Err(error) => return Err(error),
    }

    let path = Path::new(file_name);
    let stem = path
        .file_stem()
        .and_then(|value| value.to_str())
        .unwrap_or("file");
    let extension = path.extension().and_then(|value| value.to_str());
    for index in 1..10_000 {
        let candidate = match extension {
            Some(extension) => directory.join(format!("{stem} ({index}).{extension}")),
            None => directory.join(format!("{stem} ({index})")),
        };
        match tokio::fs::OpenOptions::new()
            .write(true)
            .create_new(true)
            .open(&candidate)
            .await
        {
            Ok(file) => return Ok((candidate, file)),
            Err(error) if error.kind() == ErrorKind::AlreadyExists => continue,
            Err(error) => return Err(error),
        }
    }

    let candidate = directory.join(format!("{}-{file_name}", uuid::Uuid::new_v4()));
    tokio::fs::OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(&candidate)
        .await
        .map(|file| (candidate, file))
}

async fn finish_upload_with_error(destination: &Path, message: String) -> Response<Full<Bytes>> {
    let _ = tokio::fs::remove_file(destination).await;
    finish_with_error(message)
}

fn safe_file_name(name: &str) -> String {
    Path::new(name)
        .file_name()
        .and_then(|name| name.to_str())
        .filter(|name| !name.is_empty() && *name != "." && *name != "..")
        .unwrap_or("received-file")
        .to_string()
}

fn finish_with_error(message: String) -> Response<Full<Bytes>> {
    let mut state = lock_manager();
    state.pending = None;
    state.active = None;
    state.progress.status = "failed".to_string();
    state.progress.error = Some(message.clone());
    error_response(StatusCode::INTERNAL_SERVER_ERROR, &message)
}

fn json_response<T: Serialize>(status: StatusCode, value: &T) -> Response<Full<Bytes>> {
    let body = serde_json::to_vec(value).unwrap_or_default();
    Response::builder()
        .status(status)
        .header(hyper::header::CONTENT_TYPE, "application/json")
        .body(Full::from(Bytes::from(body)))
        .unwrap()
}

fn error_response(status: StatusCode, message: &str) -> Response<Full<Bytes>> {
    json_response(
        status,
        &ErrorResponse {
            message: message.to_string(),
        },
    )
}

fn text_message(files: &HashMap<String, FileDto>) -> Option<String> {
    if files.len() != 1 {
        return None;
    }
    let file = files.values().next()?;
    if !file.file_type.starts_with("text/") {
        return None;
    }
    file.preview
        .as_ref()
        .filter(|preview| !preview.is_empty())
        .cloned()
}

fn empty_response(status: StatusCode) -> Response<Full<Bytes>> {
    Response::builder()
        .status(status)
        .body(Full::default())
        .unwrap()
}
