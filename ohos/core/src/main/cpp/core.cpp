#include "napi/native_api.h"
#include "bride.h"
#include "libclash.h"
#include <cstring>
#include <cstdlib>
#include <future>

enum class InterfaceType {
    Invoke,
    Tun,
};

struct TunInterface {
    InterfaceType type = InterfaceType::Tun;
    napi_threadsafe_function protect;
    napi_threadsafe_function resolveUid;
};

struct InvokeInterface {
    InterfaceType type = InterfaceType::Invoke;
    napi_threadsafe_function onResult;
};

struct ResolveUidCall {
    int protocol;
    const char *source;
    const char *target;
    std::promise<int> promise;
};

struct ProtectCall {
    int fd;
    std::promise<int> promise;
};

struct StartTunWork {
    napi_async_work work = nullptr;
    napi_deferred deferred = nullptr;
    TunInterface *tunInterface = nullptr;
    int fd = -1;
    char *stack = nullptr;
    char *address = nullptr;
    char *dns = nullptr;
    bool started = false;
};

struct StopTunWork {
    napi_async_work work = nullptr;
    napi_deferred deferred = nullptr;
};

static char *GetValueStringUtf8(napi_env env, napi_value value) {
    size_t length = 0;
    napi_get_value_string_utf8(env, value, nullptr, 0, &length);
    char *result = static_cast<char*>(malloc(length + 1));
    napi_get_value_string_utf8(env, value, result, length + 1, &length);
    return result;
}

static int GetValueInt32(napi_env env, napi_value value) {
    int result = 0;
    napi_get_value_int32(env, value, &result);
    return result;
}

static bool GetValueBool(napi_env env, napi_value value) {
    bool result = false;
    napi_get_value_bool(env, value, &result);
    return result;
}

static napi_value CreateValueStringUtf8(napi_env env, const char *data) {
    napi_value result = nullptr;
    napi_create_string_utf8(env, data, NAPI_AUTO_LENGTH, &result);
    return result;
}

static napi_value CreateValueInt32(napi_env env, int data) {
    napi_value result = nullptr;
    napi_create_int32(env, data, &result);
    return result;
}


void InvokeMethodCallJsCallback(napi_env env, napi_value callback, void* context, void* data){
    napi_value global = nullptr;
    napi_get_global(env, &global);
    napi_value argv = CreateValueStringUtf8(env, reinterpret_cast<char*>(data));
    napi_value result = nullptr;
    napi_call_function(env, global, callback, 1, &argv, &result);
    free(data);
}

static napi_value ProtectCallbackResolve(napi_env env, napi_callback_info info) {
    void *data = nullptr;
    napi_get_cb_info(env, info, nullptr, nullptr, nullptr, &data);
    ProtectCall *call = reinterpret_cast<ProtectCall*>(data);
    call->promise.set_value(1);
    return nullptr;
}

static napi_value ProtectCallbackReject(napi_env env, napi_callback_info info) {
    void *data = nullptr;
    napi_get_cb_info(env, info, nullptr, nullptr, nullptr, &data);
    ProtectCall *call = reinterpret_cast<ProtectCall*>(data);
    call->promise.set_value(0);
    return nullptr;
}

void ProtectCallJsCallback(napi_env env, napi_value callback, void *context, void *data) {
    ProtectCall *call = reinterpret_cast<ProtectCall*>(data);
    napi_value global = nullptr;
    napi_get_global(env, &global);
    napi_value argv = CreateValueInt32(env, call->fd);
    napi_value result = nullptr;
    napi_call_function(env, global, callback, 1, &argv, &result);
    napi_value then = nullptr;
    napi_get_named_property(env, result, "then", &then);
    napi_value resolve = nullptr;
    napi_value reject = nullptr;
    napi_create_function(env, "onProtectResolve", NAPI_AUTO_LENGTH, ProtectCallbackResolve, call, &resolve);
    napi_create_function(env, "onProtectReject", NAPI_AUTO_LENGTH, ProtectCallbackReject, call, &reject);
    napi_value thenArgs[2] = {resolve, reject};
    napi_call_function(env, result, then, 2, thenArgs, nullptr);
}

void ResolveUidCallJsCallback(napi_env env, napi_value callback, void *context, void *data) {
    ResolveUidCall *call = reinterpret_cast<ResolveUidCall*>(data);
    napi_value global = nullptr;
    napi_get_global(env, &global);
    napi_value argv[3] = {CreateValueInt32(env, call->protocol), CreateValueStringUtf8(env, call->source), CreateValueStringUtf8(env, call->target)};
    napi_value result = nullptr;
    napi_call_function(env, global, callback, 3, argv, &result);
    call->promise.set_value(GetValueInt32(env, result));
}


static napi_value InvokeMethod(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value argv[2] = {nullptr};
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    InvokeInterface *invokeInterface = new InvokeInterface();
    napi_create_threadsafe_function(env, argv[0], nullptr, CreateValueStringUtf8(env, "onResult"), 0, 1, nullptr, nullptr, nullptr, InvokeMethodCallJsCallback, &invokeInterface->onResult);
    invokeMethod(invokeInterface, GetValueStringUtf8(env, argv[1]));
    return nullptr;
}

static void ExecuteStartTun(napi_env env, void *data) {
    StartTunWork *work = reinterpret_cast<StartTunWork*>(data);
    work->started = startTUN(work->tunInterface, work->fd, work->stack, work->address, work->dns);
}

static void CompleteStartTun(napi_env env, napi_status status, void *data) {
    StartTunWork *work = reinterpret_cast<StartTunWork*>(data);
    napi_value result = nullptr;
    napi_get_boolean(env, status == napi_ok && work->started, &result);
    napi_resolve_deferred(env, work->deferred, result);
    napi_delete_async_work(env, work->work);
    delete work;
}

static napi_value StartTUN(napi_env env, napi_callback_info info) {
    size_t argc = 6;
    napi_value argv[6] = {nullptr};
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    StartTunWork *work = new StartTunWork();
    napi_value promise = nullptr;
    napi_create_promise(env, &work->deferred, &promise);
    work->fd = GetValueInt32(env, argv[2]);
    work->stack = GetValueStringUtf8(env, argv[3]);
    work->address = GetValueStringUtf8(env, argv[4]);
    work->dns = GetValueStringUtf8(env, argv[5]);
    work->tunInterface = new TunInterface();
    napi_create_threadsafe_function(env, argv[0], nullptr, CreateValueStringUtf8(env, "protect"), 0, 1, nullptr, nullptr, nullptr, ProtectCallJsCallback, &work->tunInterface->protect);
    napi_create_threadsafe_function(env, argv[1], nullptr, CreateValueStringUtf8(env, "resolveUid"), 0, 1, nullptr, nullptr, nullptr, ResolveUidCallJsCallback, &work->tunInterface->resolveUid);
    napi_create_async_work(env, nullptr, CreateValueStringUtf8(env, "startTUN"), ExecuteStartTun, CompleteStartTun, work, &work->work);
    napi_queue_async_work(env, work->work);
    return promise;
}

static napi_value QuickSetup(napi_env env, napi_callback_info info) {
    size_t argc = 3;
    napi_value argv[3] = {nullptr};
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    InvokeInterface *invokeInterface = new InvokeInterface();
    napi_create_threadsafe_function(env, argv[0], nullptr, CreateValueStringUtf8(env, "onResult"), 0, 1, nullptr, nullptr, nullptr, InvokeMethodCallJsCallback, &invokeInterface->onResult);
    quickSetup(invokeInterface, GetValueStringUtf8(env, argv[1]), GetValueStringUtf8(env, argv[2]));
    return nullptr;
}

static napi_value SetEventListener(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value argv[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    napi_valuetype type = napi_undefined;
    if (argc > 0) {
        napi_typeof(env, argv[0], &type);
    }
    if (argc == 0 || type == napi_undefined || type == napi_null) {
        setEventListener(nullptr);
        return nullptr;
    }
    InvokeInterface *invokeInterface = new InvokeInterface();
    napi_create_threadsafe_function(env, argv[0], nullptr, CreateValueStringUtf8(env, "onResult"), 0, 1, nullptr, nullptr, nullptr, InvokeMethodCallJsCallback, &invokeInterface->onResult);
    setEventListener(invokeInterface);
    return nullptr;
}

static napi_value GetTotalTraffic(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value argv[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    char *data = getTotalTraffic(GetValueBool(env, argv[0]));
    return CreateValueStringUtf8(env, data);
}

static napi_value GetTraffic(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value argv[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    char *data = getTraffic(GetValueBool(env, argv[0]));
    return CreateValueStringUtf8(env, data);
}

static void ExecuteStopTun(napi_env env, void *data) {
    stopTun();
}

static void CompleteStopTun(napi_env env, napi_status status, void *data) {
    StopTunWork *work = reinterpret_cast<StopTunWork*>(data);
    napi_value result = nullptr;
    napi_get_undefined(env, &result);
    napi_resolve_deferred(env, work->deferred, result);
    napi_delete_async_work(env, work->work);
    delete work;
}

static napi_value StopTun(napi_env env, napi_callback_info info) {
    StopTunWork *work = new StopTunWork();
    napi_value promise = nullptr;
    napi_create_promise(env, &work->deferred, &promise);
    napi_create_async_work(env, nullptr, CreateValueStringUtf8(env, "stopTun"), ExecuteStopTun, CompleteStopTun, work, &work->work);
    napi_queue_async_work(env, work->work);
    return promise;
}

static napi_value ForceGC(napi_env env, napi_callback_info info) {
    forceGC();
    return nullptr;
}

static napi_value UpdateDns(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value argv[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    updateDns(GetValueStringUtf8(env, argv[0]));
    return nullptr;
}

static int call_tun_interface_protect_impl(void *tun_interface, const int fd) {
    TunInterface *tunInterface = reinterpret_cast<TunInterface*>(tun_interface);
    ProtectCall call{fd, {}};
    std::future<int> future = call.promise.get_future();
    napi_call_threadsafe_function(tunInterface->protect, &call, napi_tsfn_nonblocking);
    return future.get();
}

static int call_tun_interface_resolve_uid_impl(void *tun_interface, const int protocol, const char *source, const char *target) {
    TunInterface *tunInterface = reinterpret_cast<TunInterface*>(tun_interface);
    ResolveUidCall call{protocol, source, target, {}};
    std::future<int> future = call.promise.get_future();
    napi_call_threadsafe_function(tunInterface->resolveUid, &call, napi_tsfn_nonblocking);
    return future.get();
}

static void call_invoke_interface_result_impl(void *invoke_interface, const char *data) {
    InvokeInterface *invokeInterface = reinterpret_cast<InvokeInterface*>(invoke_interface);
    char *dataCopy = nullptr;
    if (data != nullptr) {
        size_t length = std::strlen(data);
        dataCopy = static_cast<char*>(malloc(length + 1));
        std::memcpy(dataCopy, data, length + 1);
    }
    napi_call_threadsafe_function(invokeInterface->onResult, dataCopy, napi_tsfn_nonblocking);
}

static void release_object_impl(void *obj) {
    if (obj == nullptr) {
        return;
    }
    if (*reinterpret_cast<InterfaceType*>(obj) == InterfaceType::Tun) {
        TunInterface *tunInterface = reinterpret_cast<TunInterface*>(obj);
        napi_release_threadsafe_function(tunInterface->protect, napi_tsfn_release);
        napi_release_threadsafe_function(tunInterface->resolveUid, napi_tsfn_release);
        delete tunInterface;
        return;
    }
    InvokeInterface *invokeInterface = reinterpret_cast<InvokeInterface*>(obj);
    napi_release_threadsafe_function(invokeInterface->onResult, napi_tsfn_release);
    delete invokeInterface;
}

static void free_string_impl(char *data) {
    free(data);
}


EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports)
{
    napi_property_descriptor desc[] = {
        { "invokeMethod", nullptr, InvokeMethod, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "startTUN", nullptr, StartTUN, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "quickSetup", nullptr, QuickSetup, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "setEventListener", nullptr, SetEventListener, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "getTotalTraffic", nullptr, GetTotalTraffic, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "getTraffic", nullptr, GetTraffic, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "stopTun", nullptr, StopTun, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "forceGC", nullptr, ForceGC, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "updateDns", nullptr, UpdateDns, nullptr, nullptr, nullptr, napi_default, nullptr }
    };
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);

    protect_func = &call_tun_interface_protect_impl;
    resolve_uid_func = &call_tun_interface_resolve_uid_impl;
    result_func = &call_invoke_interface_result_impl;
    release_object_func = &release_object_impl;
    free_string_func = &free_string_impl;

    return exports;
}
EXTERN_C_END

static napi_module coreModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "core",
    .nm_priv = ((void*)0),
    .reserved = {0},
};

extern "C" __attribute__((constructor)) void RegisterCoreModule(void)
{
    napi_module_register(&coreModule);
}
