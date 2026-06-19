use rustls::client::danger::{HandshakeSignatureValid, ServerCertVerified, ServerCertVerifier};
use rustls::client::WebPkiServerVerifier;
use rustls::pki_types::pem::PemObject;
use rustls::pki_types::{CertificateDer, ServerName, UnixTime};
use rustls::{CertificateError, DigitallySignedStruct, Error, RootCertStore, SignatureScheme};
use std::fmt::{Debug, Formatter};
use std::sync::{Arc, Mutex};

pub(crate) struct LocalSendServerCertVerifier {
    signature_verifier: Arc<WebPkiServerVerifier>,
    pinned_certificate: Mutex<Option<Vec<u8>>>,
}

impl LocalSendServerCertVerifier {
    pub(crate) fn try_new(local_cert: &str) -> anyhow::Result<Self> {
        let mut roots = RootCertStore::empty();
        roots.add(CertificateDer::from_pem_slice(local_cert.as_bytes())?)?;
        Ok(Self {
            signature_verifier: WebPkiServerVerifier::builder(Arc::new(roots)).build()?,
            pinned_certificate: Mutex::new(None),
        })
    }
}

impl Debug for LocalSendServerCertVerifier {
    fn fmt(&self, formatter: &mut Formatter<'_>) -> std::fmt::Result {
        formatter
            .debug_struct("LocalSendServerCertVerifier")
            .finish_non_exhaustive()
    }
}

impl ServerCertVerifier for LocalSendServerCertVerifier {
    fn verify_server_cert(
        &self,
        end_entity: &CertificateDer<'_>,
        _: &[CertificateDer<'_>],
        _: &ServerName<'_>,
        _: &[u8],
        _: UnixTime,
    ) -> Result<ServerCertVerified, Error> {
        crate::crypto::cert::verify_cert_from_der(end_entity.as_ref(), None).map_err(|error| {
            tracing::warn!("Server certificate verification failed: {error:#}");
            Error::InvalidCertificate(CertificateError::ApplicationVerificationFailure)
        })?;

        let mut pinned = self
            .pinned_certificate
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner);
        match pinned.as_ref() {
            Some(expected) if expected.as_slice() != end_entity.as_ref() => {
                return Err(Error::InvalidCertificate(
                    CertificateError::ApplicationVerificationFailure,
                ));
            }
            Some(_) => {}
            None => *pinned = Some(end_entity.to_vec()),
        }
        Ok(ServerCertVerified::assertion())
    }

    fn verify_tls12_signature(
        &self,
        message: &[u8],
        cert: &CertificateDer<'_>,
        dss: &DigitallySignedStruct,
    ) -> Result<HandshakeSignatureValid, Error> {
        self.signature_verifier
            .verify_tls12_signature(message, cert, dss)
    }

    fn verify_tls13_signature(
        &self,
        message: &[u8],
        cert: &CertificateDer<'_>,
        dss: &DigitallySignedStruct,
    ) -> Result<HandshakeSignatureValid, Error> {
        self.signature_verifier
            .verify_tls13_signature(message, cert, dss)
    }

    fn supported_verify_schemes(&self) -> Vec<SignatureScheme> {
        self.signature_verifier.supported_verify_schemes()
    }
}
