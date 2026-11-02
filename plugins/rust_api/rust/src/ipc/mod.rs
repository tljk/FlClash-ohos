#[cfg(not(any(target_os = "android", target_env = "ohos")))]
mod frame;
#[cfg(not(any(target_os = "android", target_env = "ohos")))]
mod platform;
#[cfg(not(any(target_os = "android", target_env = "ohos")))]
mod queue;
#[cfg(not(any(target_os = "android", target_env = "ohos")))]
mod server;
#[cfg(any(target_os = "android", target_env = "ohos"))]
mod unsupported;

#[cfg(not(any(target_os = "android", target_env = "ohos")))]
pub use server::{restart_server, send_message, stop_server};
#[cfg(any(target_os = "android", target_env = "ohos"))]
pub use unsupported::{restart_server, send_message, stop_server};
