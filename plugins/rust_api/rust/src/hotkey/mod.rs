#[cfg(not(any(target_os = "android", target_env = "ohos")))]
mod keys;
#[cfg(not(any(target_os = "android", target_env = "ohos")))]
mod owner;
#[cfg(not(any(target_os = "android", target_env = "ohos")))]
mod service;
#[cfg(any(target_os = "android", target_env = "ohos"))]
mod unsupported;

#[cfg(not(any(target_os = "android", target_env = "ohos")))]
pub use service::{listen, set_hot_keys};
#[cfg(any(target_os = "android", target_env = "ohos"))]
pub use unsupported::{listen, set_hot_keys};
