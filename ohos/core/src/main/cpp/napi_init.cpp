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
    napi_threadsafe_function resolverProcess;
};

struct InvokeInterface {
    InterfaceType type = InterfaceType::Invoke;
    napi_threadsafe_function onResult;
};

struct ResolveProcessCall {
    int protocol;
    const char *source;
    const char *target;
    int uid;
    std::promise<char*> promise;
};

struct ProtectCall {
    int fd;
    std::promise<void> promise;
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


void InvokeActionCallJsCallback(napi_env env, napi_value callback, void* context, void* data){
    napi_value global = nullptr;
    napi_get_global(env, &global);
    napi_value argv = CreateValueStringUtf8(env, reinterpret_cast<char*>(data));
    napi_value result = nullptr;
    napi_call_function(env, global, callback, 1, &argv, &result);
    free(data);
}

static napi_value ProtectCallbackFinal(napi_env env, napi_callback_info info) {
    void *data = nullptr;
    napi_get_cb_info(env, info, nullptr, nullptr, nullptr, &data);
    ProtectCall *call = reinterpret_cast<ProtectCall*>(data);
    call->promise.set_value();
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
    napi_value final = nullptr;
    napi_create_function(env, "onProtectFinal", NAPI_AUTO_LENGTH, ProtectCallbackFinal, call, &final);
    napi_value thenArgs[2] = {final, final};
    napi_value thenResult = nullptr;
    napi_call_function(env, result, then, 2, thenArgs, &thenResult);
}

void ResolveProcessCallJsCallback(napi_env env, napi_value callback, void *context, void *data) {
    ResolveProcessCall *call = reinterpret_cast<ResolveProcessCall*>(data);
    napi_value global = nullptr;
    napi_get_global(env, &global);
    napi_value argv[4] = {CreateValueInt32(env, call->protocol), CreateValueStringUtf8(env, call->source), CreateValueStringUtf8(env, call->target), CreateValueInt32(env, call->uid)};
    napi_value result = nullptr;
    napi_call_function(env, global, callback, 4, argv, &result);
    char *resultStr = GetValueStringUtf8(env, result);
    call->promise.set_value(resultStr);
}


static napi_value InvokeAction(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value argv[2] = {nullptr};
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    InvokeInterface *invokeInterface = new InvokeInterface();
    napi_create_threadsafe_function(env, argv[0], nullptr, CreateValueStringUtf8(env, "onResult"), 0, 1, nullptr, nullptr, nullptr, InvokeActionCallJsCallback, &invokeInterface->onResult);
    invokeAction(invokeInterface, GetValueStringUtf8(env, argv[1]));
    return nullptr;
}

static napi_value StartTUN(napi_env env, napi_callback_info info) {
    size_t argc = 6;
    napi_value argv[6] = {nullptr};
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    TunInterface *tunInterface = new TunInterface();
    napi_create_threadsafe_function(env, argv[0], nullptr, CreateValueStringUtf8(env, "protect"), 0, 1, nullptr, nullptr, nullptr, ProtectCallJsCallback, &tunInterface->protect);
    napi_create_threadsafe_function(env, argv[1], nullptr, CreateValueStringUtf8(env, "resolverProcess"), 0, 1, nullptr, nullptr, nullptr, ResolveProcessCallJsCallback, &tunInterface->resolverProcess);
    startTUN(tunInterface, GetValueInt32(env, argv[2]), GetValueStringUtf8(env, argv[3]), GetValueStringUtf8(env, argv[4]), GetValueStringUtf8(env, argv[5]));
    return nullptr;
}

static napi_value QuickSetup(napi_env env, napi_callback_info info) {
    size_t argc = 3;
    napi_value argv[3] = {nullptr};
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    InvokeInterface *invokeInterface = new InvokeInterface();
    napi_create_threadsafe_function(env, argv[0], nullptr, CreateValueStringUtf8(env, "onResult"), 0, 1, nullptr, nullptr, nullptr, InvokeActionCallJsCallback, &invokeInterface->onResult);
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
    napi_create_threadsafe_function(env, argv[0], nullptr, CreateValueStringUtf8(env, "onResult"), 0, 1, nullptr, nullptr, nullptr, InvokeActionCallJsCallback, &invokeInterface->onResult);
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

static napi_value StopTun(napi_env env, napi_callback_info info) {
    stopTun();
    return nullptr;
}

static napi_value Suspend(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value argv[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    suspend(GetValueBool(env, argv[0]));
    return nullptr;
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

static void call_tun_interface_protect_impl(void *tun_interface, const int fd) {
    TunInterface *tunInterface = reinterpret_cast<TunInterface*>(tun_interface);
    ProtectCall call{fd, {}};
    std::future<void> future = call.promise.get_future();
    napi_call_threadsafe_function(tunInterface->protect, &call, napi_tsfn_nonblocking);
    future.wait();
}

static char *call_tun_interface_resolve_process_impl(void *tun_interface, const int protocol, const char *source, const char *target, const int uid) {
    TunInterface *tunInterface = reinterpret_cast<TunInterface*>(tun_interface);
    ResolveProcessCall data{protocol, source, target, uid, {}};
    std::future<char*> future = data.promise.get_future();
    napi_call_threadsafe_function(tunInterface->resolverProcess, &data, napi_tsfn_nonblocking);
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
        napi_release_threadsafe_function(tunInterface->resolverProcess, napi_tsfn_release);
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
        { "invokeAction", nullptr, InvokeAction, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "startTUN", nullptr, StartTUN, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "quickSetup", nullptr, QuickSetup, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "setEventListener", nullptr, SetEventListener, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "getTotalTraffic", nullptr, GetTotalTraffic, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "getTraffic", nullptr, GetTraffic, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "stopTun", nullptr, StopTun, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "suspend", nullptr, Suspend, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "forceGC", nullptr, ForceGC, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "updateDns", nullptr, UpdateDns, nullptr, nullptr, nullptr, napi_default, nullptr }
    };
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);

    protect_func = &call_tun_interface_protect_impl;
    resolve_process_func = &call_tun_interface_resolve_process_impl;
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
