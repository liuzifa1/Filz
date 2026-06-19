use rcgen::{CertificateParams, DistinguishedName, DnType, KeyPair};
use serde::Serialize;
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::{Mutex, OnceLock};

const CERTIFICATE_FILE: &str = "certificate.pem";
const PRIVATE_KEY_FILE: &str = "private-key.pem";

#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct TlsIdentity {
    pub cert: String,
    pub private_key: String,
}

static TLS_IDENTITY: OnceLock<Mutex<Option<TlsIdentity>>> = OnceLock::new();

fn identity_slot() -> &'static Mutex<Option<TlsIdentity>> {
    TLS_IDENTITY.get_or_init(|| Mutex::new(None))
}

pub(crate) fn configure(directory: &Path, common_name: &str) -> anyhow::Result<()> {
    fs::create_dir_all(directory)?;
    let cert_path = directory.join(CERTIFICATE_FILE);
    let key_path = directory.join(PRIVATE_KEY_FILE);

    let identity = match load(&cert_path, &key_path) {
        Ok(identity) => identity,
        Err(_) => {
            let identity = generate(common_name)?;
            write_private(&cert_path, identity.cert.as_bytes())?;
            write_private(&key_path, identity.private_key.as_bytes())?;
            identity
        }
    };
    validate(&identity)?;
    *identity_slot()
        .lock()
        .unwrap_or_else(std::sync::PoisonError::into_inner) = Some(identity);
    Ok(())
}

pub(crate) fn current() -> anyhow::Result<TlsIdentity> {
    identity_slot()
        .lock()
        .unwrap_or_else(std::sync::PoisonError::into_inner)
        .clone()
        .ok_or_else(|| anyhow::anyhow!("TLS identity is not configured"))
}

fn load(cert_path: &Path, key_path: &Path) -> anyhow::Result<TlsIdentity> {
    let identity = TlsIdentity {
        cert: fs::read_to_string(cert_path)?,
        private_key: fs::read_to_string(key_path)?,
    };
    validate(&identity)?;
    Ok(identity)
}

fn generate(common_name: &str) -> anyhow::Result<TlsIdentity> {
    let mut params = CertificateParams::new(vec!["filz.local".to_string()])?;
    let mut distinguished_name = DistinguishedName::new();
    distinguished_name.push(
        DnType::CommonName,
        if common_name.trim().is_empty() {
            "Filz!"
        } else {
            common_name.trim()
        },
    );
    params.distinguished_name = distinguished_name;
    let key_pair = KeyPair::generate()?;
    let cert = params.self_signed(&key_pair)?;
    Ok(TlsIdentity {
        cert: cert.pem(),
        private_key: key_pair.serialize_pem(),
    })
}

fn validate(identity: &TlsIdentity) -> anyhow::Result<()> {
    crate::crypto::cert::verify_cert_from_pem(identity.cert.clone(), None)?;
    let pem = [
        identity.cert.as_bytes(),
        b"\n",
        identity.private_key.as_bytes(),
    ]
    .concat();
    reqwest::Identity::from_pem(&pem)?;
    Ok(())
}

fn write_private(path: &PathBuf, contents: &[u8]) -> anyhow::Result<()> {
    let temporary = path.with_extension("tmp");
    fs::write(&temporary, contents)?;
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        fs::set_permissions(&temporary, fs::Permissions::from_mode(0o600))?;
    }
    fs::rename(temporary, path)?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn identity_is_persisted_and_reused() {
        let directory = std::env::temp_dir().join(format!(
            "localsendcore-tls-identity-{}",
            uuid::Uuid::new_v4()
        ));
        fs::create_dir_all(&directory).unwrap();
        let first = generate("Filz Test").unwrap();
        let cert_path = directory.join(CERTIFICATE_FILE);
        let key_path = directory.join(PRIVATE_KEY_FILE);
        write_private(&cert_path, first.cert.as_bytes()).unwrap();
        write_private(&key_path, first.private_key.as_bytes()).unwrap();
        let second = load(&cert_path, &key_path).unwrap();
        assert_eq!(first.cert, second.cert);
        assert_eq!(first.private_key, second.private_key);
        let _ = fs::remove_dir_all(directory);
    }
}
