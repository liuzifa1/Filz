use crate::http::dto::{ErrorResponse, PrepareUploadRequestDto, PrepareUploadResponseDto};
use crate::model::transfer::FileDto;
use bytes::Bytes;
use http_body_util::{BodyExt, Full};
use hyper::body::Incoming;
use hyper::{Response, StatusCode};
use serde::Serialize;
use std::collections::HashMap;
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
}

#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct IncomingRequest {
    pub id: String,
    pub sender_alias: String,
    pub sender_ip: String,
    pub files: Vec<IncomingFile>,
    pub total_bytes: u64,
}

#[derive(Clone, Default, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ReceiveProgress {
    pub status: String,
    pub sender_alias: String,
    pub current_file: Option<String>,
    pub received_bytes: u64,
    pub total_bytes: u64,
    pub completed_files: usize,
    pub total_files: usize,
    pub saved_paths: Vec<String>,
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
    pending: Option<PendingRequest>,
    active: Option<ActiveSession>,
    progress: ReceiveProgress,
}

impl Default for ReceiveManager {
    fn default() -> Self {
        Self {
            directory: std::env::temp_dir().join("LiquidSend Received Files"),
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

pub fn set_directory(path: String) -> Result<(), String> {
    let path = PathBuf::from(path);
    std::fs::create_dir_all(&path).map_err(|error| error.to_string())?;
    lock_manager().directory = path;
    Ok(())
}

pub fn pending_json() -> String {
    serde_json::to_string(
        &lock_manager()
            .pending
            .as_ref()
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
        pending
            .decision
            .take()
            .ok_or_else(|| "The receive request was already answered".to_string())?
    };
    sender
        .send(accepted)
        .map_err(|_| "The sender disconnected before the decision was delivered".to_string())
}

pub async fn prepare_upload(body: Incoming, sender_ip: IpAddr) -> Response<Full<Bytes>> {
    let payload = match body.collect().await {
        Ok(body) => match serde_json::from_slice::<PrepareUploadRequestDto>(&body.to_bytes()) {
            Ok(payload) => payload,
            Err(_) => return error_response(StatusCode::BAD_REQUEST, "Request body malformed"),
        },
        Err(_) => return error_response(StatusCode::BAD_REQUEST, "Could not read request body"),
    };
    if payload.files.is_empty() {
        return error_response(
            StatusCode::BAD_REQUEST,
            "Request must contain at least one file",
        );
    }

    let request_id = uuid::Uuid::new_v4().to_string();
    let total_bytes = payload.files.values().map(|file| file.size).sum();
    let public = IncomingRequest {
        id: request_id.clone(),
        sender_alias: payload.info.alias.clone(),
        sender_ip: sender_ip.to_string(),
        files: payload
            .files
            .values()
            .map(|file| IncomingFile {
                id: file.id.clone(),
                file_name: file.file_name.clone(),
                size: file.size,
                file_type: file.file_type.clone(),
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
            status: "waiting".to_string(),
            sender_alias: payload.info.alias.clone(),
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
    json_response(
        StatusCode::OK,
        &PrepareUploadResponseDto {
            session_id,
            files: response_files,
        },
    )
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
    mut body: Incoming,
    sender_ip: IpAddr,
    session_id: &str,
    file_id: &str,
    token: &str,
) -> Response<Full<Bytes>> {
    let (directory, file_name, expected_size) = {
        let state = lock_manager();
        let Some(session) = state.active.as_ref() else {
            return error_response(StatusCode::CONFLICT, "No session");
        };
        if session.sender_ip != sender_ip || session.id != session_id {
            return error_response(StatusCode::FORBIDDEN, "Invalid session");
        }
        let Some(file) = session.files.get(file_id) else {
            return error_response(StatusCode::FORBIDDEN, "Invalid file id");
        };
        if file.token != token || file.finished {
            return error_response(StatusCode::FORBIDDEN, "Invalid token");
        }
        (
            state.directory.clone(),
            safe_file_name(&file.file.file_name),
            file.file.size,
        )
    };

    if let Err(error) = tokio::fs::create_dir_all(&directory).await {
        return finish_with_error(format!("Could not create receive directory: {error}"));
    }
    let destination = unique_path(&directory, &file_name).await;
    let mut output = match tokio::fs::File::create(&destination).await {
        Ok(file) => file,
        Err(error) => return finish_with_error(format!("Could not create received file: {error}")),
    };

    while let Some(frame) = body.frame().await {
        let frame = match frame {
            Ok(frame) => frame,
            Err(error) => return finish_with_error(format!("Upload interrupted: {error}")),
        };
        if let Some(data) = frame.data_ref() {
            if let Err(error) = output.write_all(data).await {
                return finish_with_error(format!("Could not save received file: {error}"));
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
        return finish_with_error(format!("Could not finish received file: {error}"));
    }

    let mut state = lock_manager();
    let (actual_size, all_finished) = {
        let Some(session) = state.active.as_mut() else {
            return error_response(StatusCode::CONFLICT, "Session was canceled");
        };
        let Some(file) = session.files.get_mut(file_id) else {
            return error_response(StatusCode::FORBIDDEN, "Invalid file id");
        };
        let actual_size = file.received;
        if actual_size == expected_size {
            file.finished = true;
            file.path = Some(destination.clone());
        }
        (
            actual_size,
            session.files.values().all(|file| file.finished),
        )
    };
    if actual_size != expected_size {
        let message = format!("Expected {expected_size} bytes but received {actual_size}");
        state.progress.status = "failed".to_string();
        state.progress.error = Some(message.clone());
        return error_response(StatusCode::INTERNAL_SERVER_ERROR, &message);
    }
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
    empty_response(StatusCode::OK)
}

pub fn cancel(sender_ip: IpAddr, session_id: Option<&str>) -> Response<Full<Bytes>> {
    let mut state = lock_manager();
    if let Some(pending) = state.pending.as_ref() {
        if pending.sender_ip == sender_ip {
            if let Some(sender) = state
                .pending
                .as_mut()
                .and_then(|pending| pending.decision.take())
            {
                let _ = sender.send(false);
            }
            state.progress.status = "canceled".to_string();
            return empty_response(StatusCode::OK);
        }
    }
    if let Some(active) = state.active.as_ref() {
        if active.sender_ip == sender_ip && session_id == Some(active.id.as_str()) {
            state.active = None;
            state.progress.status = "canceled".to_string();
            return empty_response(StatusCode::OK);
        }
    }
    error_response(StatusCode::FORBIDDEN, "No permission")
}

fn safe_file_name(name: &str) -> String {
    Path::new(name)
        .file_name()
        .and_then(|name| name.to_str())
        .filter(|name| !name.is_empty() && *name != "." && *name != "..")
        .unwrap_or("received-file")
        .to_string()
}

async fn unique_path(directory: &Path, file_name: &str) -> PathBuf {
    let initial = directory.join(file_name);
    if tokio::fs::metadata(&initial).await.is_err() {
        return initial;
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
        if tokio::fs::metadata(&candidate).await.is_err() {
            return candidate;
        }
    }
    directory.join(format!("{}-{file_name}", uuid::Uuid::new_v4()))
}

fn finish_with_error(message: String) -> Response<Full<Bytes>> {
    let mut state = lock_manager();
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

fn empty_response(status: StatusCode) -> Response<Full<Bytes>> {
    Response::builder()
        .status(status)
        .body(Full::default())
        .unwrap()
}
