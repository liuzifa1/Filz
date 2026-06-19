mod client_cert_verifier;
mod collect_to_json;
mod controller;
mod error;
mod response;

use crate::crypto::cert::public_key_from_cert_der;
use crate::http::server::client_cert_verifier::CustomClientCertVerifier;
use crate::http::server::controller::web::WebPageState;
use crate::http::server::error::AppError;
use crate::http::state::ClientInfo;
use bytes::Bytes;
use http_body_util::Full;
use hyper::body::Incoming;
use hyper::{Method, Request, Response, StatusCode};
use hyper_util::rt::{TokioExecutor, TokioIo};
use hyper_util::server::conn::auto::Builder;
use lru::LruCache;
use rustls::pki_types::pem::PemObject;
use rustls::pki_types::{CertificateDer, PrivateKeyDer};
use std::fmt::Debug;
use std::net::{IpAddr, Ipv4Addr, SocketAddr};
use std::num::NonZeroUsize;
use std::ops::Deref;
use std::sync::mpsc::SyncSender;
use std::sync::Arc;
use tokio::sync::{oneshot, Mutex};

#[derive(serde::Serialize)]
#[serde(rename_all = "camelCase")]
struct LegacyInfoResponse {
    alias: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    device_model: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    device_type: Option<crate::model::discovery::DeviceType>,
}

#[derive(Clone)]
struct AppState {
    /// Information about server's device.
    info: Arc<Mutex<ClientInfo>>,

    /// State for serving web pages.
    web: Arc<Mutex<Option<WebPageState>>>,

    /// Maps client identifiers to nonces that have been received from remote.
    received_nonce_map: Arc<Mutex<LruCache<String, Vec<u8>>>>,

    /// Maps client identifiers to nonces that are expected to be received from remote.
    generated_nonce_map: Arc<Mutex<LruCache<String, Vec<u8>>>>,
}

impl AppState {
    fn new(info: Arc<Mutex<ClientInfo>>) -> Self {
        Self {
            info,
            web: Arc::new(Mutex::new(None)),
            received_nonce_map: Arc::new(Mutex::new(LruCache::new(
                NonZeroUsize::new(200).unwrap(),
            ))),
            generated_nonce_map: Arc::new(Mutex::new(LruCache::new(
                NonZeroUsize::new(200).unwrap(),
            ))),
        }
    }
}

/// Binds the server to the specified port on both IPv4 and IPv6 addresses.
pub async fn start_with_port(
    port: u16,
    tls_config: Option<TlsConfig>,
    info: ClientInfo,
    legacy_enabled: bool,
    stop_rx: oneshot::Receiver<()>,
) -> anyhow::Result<()> {
    tokio::spawn(async move {
        if let Err(err) = run_with_port(port, tls_config, info, legacy_enabled, stop_rx).await {
            tracing::error!("Server failed: {err:#}");
        }
    });

    Ok(())
}

/// Runs the server until it fails or receives a stop signal.
pub async fn run_with_port(
    port: u16,
    tls_config: Option<TlsConfig>,
    info: ClientInfo,
    legacy_enabled: bool,
    stop_rx: oneshot::Receiver<()>,
) -> anyhow::Result<()> {
    run_with_port_inner(port, tls_config, info, legacy_enabled, stop_rx, None).await
}

pub async fn run_with_port_and_ready(
    port: u16,
    tls_config: Option<TlsConfig>,
    info: ClientInfo,
    legacy_enabled: bool,
    stop_rx: oneshot::Receiver<()>,
    ready_tx: SyncSender<Result<(), String>>,
) -> anyhow::Result<()> {
    run_with_port_inner(
        port,
        tls_config,
        info,
        legacy_enabled,
        stop_rx,
        Some(ready_tx),
    )
    .await
}

async fn run_with_port_inner(
    port: u16,
    tls_config: Option<TlsConfig>,
    info: ClientInfo,
    legacy_enabled: bool,
    stop_rx: oneshot::Receiver<()>,
    ready_tx: Option<SyncSender<Result<(), String>>>,
) -> anyhow::Result<()> {
    let ipv4_socket_addr = SocketAddr::new(Ipv4Addr::UNSPECIFIED.into(), port);
    let info = Arc::new(Mutex::new(info));
    let state = AppState::new(info.clone());

    tokio::select! {
        result = start_server_with_addr(ipv4_socket_addr, tls_config, state, legacy_enabled, ready_tx) => {
            result
        }
        _ = stop_rx => {
            tracing::info!("Server stopped on port {port}");
            Ok(())
        }
    }
}

#[derive(Clone, Debug)]
pub struct TlsConfig {
    pub cert: String,
    pub private_key: String,
}

async fn start_server_with_addr(
    socket_addr: SocketAddr,
    tls_config: Option<TlsConfig>,
    app_state: AppState,
    legacy_enabled: bool,
    ready_tx: Option<SyncSender<Result<(), String>>>,
) -> anyhow::Result<()> {
    let _ = rustls::crypto::ring::default_provider().install_default();

    let incoming = match tokio::net::TcpListener::bind(socket_addr).await {
        Ok(listener) => {
            if let Some(ready_tx) = ready_tx {
                let _ = ready_tx.send(Ok(()));
            }
            listener
        }
        Err(error) => {
            if let Some(ready_tx) = ready_tx {
                let _ = ready_tx.send(Err(error.to_string()));
            }
            return Err(error.into());
        }
    };

    let tls_acceptor = match tls_config {
        Some(tls_config) => Some(create_tls_config(&tls_config).inspect_err(|err| {
            tracing::error!("failed to create tls config: {err:#}");
        })?),
        None => None,
    };

    tracing::info!(
        "Started server on {} (TLS: {})",
        socket_addr,
        tls_acceptor.is_some()
    );

    loop {
        let (tcp_stream, remote_addr) = incoming.accept().await?;

        let tls_acceptor = tls_acceptor.clone();
        let app_state = app_state.clone();
        tokio::spawn(async move {
            let res = match tls_acceptor {
                Some(tls_acceptor) => {
                    let tls_stream = match tls_acceptor.accept(tcp_stream).await {
                        Ok(tls_stream) => tls_stream,
                        Err(err) => {
                            tracing::warn!("TLS handshake error: {err:#}");
                            return;
                        }
                    };

                    let client_info = {
                        let (_, server_connection) = tls_stream.get_ref();
                        RequestClientInfo {
                            ip: remote_addr.ip(),
                            cert: server_connection
                                .deref()
                                .deref()
                                .peer_certificates()
                                .map(|cert| cert.get(0).unwrap().to_vec()),
                        }
                    };

                    Builder::new(TokioExecutor::new())
                        .serve_connection(
                            TokioIo::new(tls_stream),
                            hyper::service::service_fn(move |mut req: Request<Incoming>| {
                                req.extensions_mut()
                                    .insert::<RequestClientInfo>(client_info.clone());
                                req.extensions_mut().insert::<AppState>(app_state.clone());
                                handle_request(req, legacy_enabled)
                            }),
                        )
                        .await
                }
                None => {
                    Builder::new(TokioExecutor::new())
                        .serve_connection(
                            TokioIo::new(tcp_stream),
                            hyper::service::service_fn(move |mut req: Request<Incoming>| {
                                req.extensions_mut().insert::<RequestClientInfo>(
                                    RequestClientInfo {
                                        ip: remote_addr.ip(),
                                        cert: None,
                                    },
                                );
                                req.extensions_mut().insert::<AppState>(app_state.clone());
                                handle_request(req, legacy_enabled)
                            }),
                        )
                        .await
                }
            };

            if let Err(err) = res {
                tracing::warn!("Failed to serve connection: {err:#}");
            }
        });
    }
}

fn create_tls_config(tls_config: &TlsConfig) -> anyhow::Result<tokio_rustls::TlsAcceptor> {
    let config = {
        let certs = vec![CertificateDer::from_pem_slice(&tls_config.cert.as_bytes())?];
        let key = PrivateKeyDer::from_pem_slice(&tls_config.private_key.as_bytes())?;

        rustls::ServerConfig::builder()
            .with_client_cert_verifier(Arc::new(CustomClientCertVerifier::try_new(
                &tls_config.cert,
            )?))
            .with_single_cert(certs, key)?
    };
    Ok(tokio_rustls::TlsAcceptor::from(Arc::new(config)))
}

#[derive(Clone, Debug)]
struct RequestClientInfo {
    /// The IP address of the client.
    ip: IpAddr,

    /// The client certificate in DER format.
    cert: Option<Vec<u8>>,
}

impl RequestClientInfo {
    fn extract_public_key(&self) -> Option<String> {
        match &self.cert {
            Some(cert) => match public_key_from_cert_der(cert) {
                Ok(public_key) => Some(public_key),
                Err(err) => {
                    tracing::warn!("Failed to extract public key from certificate: {err:#}");
                    None
                }
            },
            None => None,
        }
    }

    fn identifier(&self) -> String {
        self.extract_public_key()
            .unwrap_or_else(|| self.ip.to_string())
    }

    fn fingerprint(&self) -> Option<String> {
        self.cert.as_ref().map(|cert| {
            crate::crypto::hash::sha256(cert)
                .iter()
                .map(|byte| format!("{byte:02x}"))
                .collect()
        })
    }
}

async fn handle_request(
    req: Request<Incoming>,
    legacy_enabled: bool,
) -> Result<Response<Full<Bytes>>, hyper::Error> {
    Ok(handle_request_inner(req, legacy_enabled)
        .await
        .unwrap_or_else(|err| {
            tracing::error!("Error handling request: {err:?}");
            err.to_response()
        }))
}

async fn handle_request_inner(
    mut req: Request<Incoming>,
    legacy_enabled: bool,
) -> Result<Response<Full<Bytes>>, AppError> {
    let Some(state) = req.extensions_mut().remove::<AppState>() else {
        return Err(AppError::Status(StatusCode::INTERNAL_SERVER_ERROR));
    };

    let Some(client_info) = req.extensions_mut().remove::<RequestClientInfo>() else {
        return Err(AppError::Status(StatusCode::INTERNAL_SERVER_ERROR));
    };

    match (req.method(), req.uri().path()) {
        (&Method::GET, "/api/localsend/v1/info") => {
            if !legacy_enabled {
                return Err(AppError::Status(StatusCode::NOT_FOUND));
            }
            let info = state.info.lock().await.clone();
            Ok(json_response(
                StatusCode::OK,
                &LegacyInfoResponse {
                    alias: info.alias,
                    device_model: info.device_model,
                    device_type: info.device_type,
                },
            ))
        }
        (&Method::POST, "/api/localsend/v1/send-request") => {
            if !legacy_enabled {
                return Err(AppError::Status(StatusCode::NOT_FOUND));
            }
            let query = query_parameters(req.uri().query());
            Ok(crate::receive::prepare_upload_v1(
                req.into_body(),
                client_info.ip,
                query.get("pin").map(String::as_str),
                client_info
                    .fingerprint()
                    .unwrap_or_else(|| client_info.identifier()),
            )
            .await)
        }
        (&Method::POST, "/api/localsend/v1/send") => {
            if !legacy_enabled {
                return Err(AppError::Status(StatusCode::NOT_FOUND));
            }
            let query = query_parameters(req.uri().query());
            let file_id = query.get("fileId").map(String::as_str).unwrap_or("");
            let token = query.get("token").map(String::as_str).unwrap_or("");
            Ok(crate::receive::upload_v1(req.into_body(), client_info.ip, file_id, token).await)
        }
        (&Method::POST, "/api/localsend/v1/cancel") => {
            if !legacy_enabled {
                return Err(AppError::Status(StatusCode::NOT_FOUND));
            }
            Ok(crate::receive::cancel(client_info.ip, None))
        }
        (&Method::GET, "/api/localsend/v2/info") => {
            if !legacy_enabled {
                return Err(AppError::Status(StatusCode::NOT_FOUND));
            }
            let info = state.info.lock().await.clone();
            let has_web_interface = state.web.lock().await.is_some();
            Ok(json_response(
                StatusCode::OK,
                &crate::http::dto::RegisterResponseDto {
                    alias: info.alias,
                    version: info.version,
                    device_model: info.device_model,
                    device_type: info.device_type,
                    token: info.token,
                    has_web_interface,
                },
            ))
        }
        (&Method::POST, "/api/localsend/v2/register") => {
            if !legacy_enabled {
                return Err(AppError::Status(StatusCode::NOT_FOUND));
            }

            Ok(
                controller::v2::register(req.into_body(), state, client_info)
                    .await?
                    .into_response(),
            )
        }
        (&Method::POST, "/api/localsend/v2/prepare-upload") => {
            if !legacy_enabled {
                return Err(AppError::Status(StatusCode::NOT_FOUND));
            }

            let query = query_parameters(req.uri().query());
            Ok(crate::receive::prepare_upload(
                req.into_body(),
                client_info.ip,
                query.get("pin").map(String::as_str),
                client_info.fingerprint(),
            )
            .await)
        }
        (&Method::POST, "/api/localsend/v2/upload") => {
            if !legacy_enabled {
                return Err(AppError::Status(StatusCode::NOT_FOUND));
            }

            let query = query_parameters(req.uri().query());
            let session_id = query.get("sessionId").map(String::as_str).unwrap_or("");
            let file_id = query.get("fileId").map(String::as_str).unwrap_or("");
            let token = query.get("token").map(String::as_str).unwrap_or("");
            Ok(
                crate::receive::upload(req.into_body(), client_info.ip, session_id, file_id, token)
                    .await,
            )
        }
        (&Method::POST, "/api/localsend/v2/cancel") => {
            if !legacy_enabled {
                return Err(AppError::Status(StatusCode::NOT_FOUND));
            }

            let query = query_parameters(req.uri().query());
            Ok(crate::receive::cancel(
                client_info.ip,
                query.get("sessionId").map(String::as_str),
            ))
        }
        (&Method::POST, "/api/localsend/v3/nonce") => {
            Ok(
                controller::v3::nonce_exchange(req.into_body(), state, client_info)
                    .await?
                    .into_response(),
            )
        }
        (&Method::POST, "/api/localsend/v3/register") => {
            Ok(
                controller::v3::register(req.into_body(), state, client_info)
                    .await?
                    .into_response(),
            )
        }
        _ => {
            let mut res = Response::new(Full::default());
            *res.status_mut() = StatusCode::NOT_FOUND;
            Ok(res)
        }
    }
}

fn json_response<T: serde::Serialize>(status: StatusCode, value: &T) -> Response<Full<Bytes>> {
    let body = serde_json::to_vec(value).unwrap_or_default();
    Response::builder()
        .status(status)
        .header(hyper::header::CONTENT_TYPE, "application/json")
        .body(Full::from(Bytes::from(body)))
        .unwrap()
}

fn query_parameters(query: Option<&str>) -> std::collections::HashMap<String, String> {
    query
        .unwrap_or_default()
        .split('&')
        .filter_map(|part| part.split_once('='))
        .map(|(key, value)| (key.to_string(), value.to_string()))
        .collect()
}
