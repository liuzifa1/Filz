use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Deserialize, Eq, Serialize, PartialEq)]
pub enum DeviceType {
    #[serde(rename = "mobile", alias = "MOBILE")]
    Mobile,
    #[serde(rename = "desktop", alias = "DESKTOP")]
    Desktop,
    #[serde(rename = "web", alias = "WEB")]
    Web,
    #[serde(rename = "headless", alias = "HEADLESS")]
    Headless,
    #[serde(rename = "server", alias = "SERVER")]
    Server,
}
