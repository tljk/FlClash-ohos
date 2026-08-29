import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
} from '@ohos/flutter_ohos';
import { CallbackStub, ResultStub } from '../entryability/EntryAbility'
import { State, VpnOptions } from '../models/State'
import { formProvider } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import { publishEvent } from '../utils/Event'
import { globalState, RunState } from '../GlobalState';
import EntryAbility from '../entryability/EntryAbility';

export default class ServicePlugin implements FlutterPlugin, MethodCallHandler {
  private parent: EntryAbility
  private channel: MethodChannel | undefined

  constructor(entryAbility: EntryAbility) {
    this.parent = entryAbility
  }

  getUniqueClassName(): string {
    return "ServicePlugin"
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), "com.follow.clash/service")
    this.channel.setMethodCallHandler(this)
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    if (this.channel != null) {
      this.channel.setMethodCallHandler(null)
    }
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    if (call.method === "init") {
      this.handleInit(result)
    } else if (call.method === "shutdown") {
      this.handleShutdown(result)
    } else if (call.method === "syncState") {
      this.handleSyncState(call, result)
    } else if (call.method === "invokeAction") {
      this.handleInvokeAction(call, result)
    } else if (call.method === "start") {
      this.handleStart(result)
    } else if (call.method === "stop") {
      this.handleStop(result)
    } else if (call.method === "getRunTime") {
      this.handleGetRunTime(result)
    } else {
      result.notImplemented()
    }
  }

  private handleInit(result: MethodResult): void {
    const callbackStub = new CallbackStub("setEventListener", (data: string) => { this.channel?.invokeMethod("event", data) })
    this.parent.handleInit(callbackStub).then(() => {
      result.success("")
    }).catch((err: Error) => {
      result.success(err.message ?? `${err}`)
    })
    this.parent.setOnDisconnected((message: string) => {
      globalState.runTime = 0
      globalState.runState = RunState.stop
      this.channel?.invokeMethod("crash", message)
      publishEvent('SERVICE_STOP', `${globalState.runTime}`)
    })
  }

  private handleShutdown(result: MethodResult): void {
    this.parent.handleShutdown().finally(() => {
      globalState.runTime = 0
      globalState.runState = RunState.stop
      result.success(true)
    })
  }

  private handleSyncState(call: MethodCall, result: MethodResult): void {
    globalState.state = JSON.parse(call.args) as State
    globalState.runState = globalState.runTime === 0 ? RunState.stop : RunState.start
    result.success("")
  }

  private handleInvokeAction(call: MethodCall, result: MethodResult): void {
    const callbackStub = new CallbackStub("invokeAction", (data: string) => { result.success(data) })
    this.parent.handleInvokeAction(call.args, callbackStub)
  }

  private handleStart(result: MethodResult): void {
    if (globalState.runState === RunState.stop) {
      globalState.runState = RunState.pending
      const options = globalState.state?.vpnOptions ?? new VpnOptions()
      const resultStub = new ResultStub("handleStart", (runTime: number) => {
        globalState.runTime = runTime
        globalState.runState = runTime !== 0 ? RunState.start : RunState.stop
        if (globalState.excludeFromRecent) {
          const want: Want = {
            bundleName: this.parent.context.applicationInfo.name,
            abilityName: 'FormExtAbility',
            parameters: {
              'ohos.extra.param.key.form_dimension': 1,
              'ohos.extra.param.key.form_name': '',
              'ohos.extra.param.key.module_name': 'entry'
            },
          }
          formProvider.openFormManager(want)
        }
      })
      this.parent.handleStartService(options, globalState.runTime, resultStub).catch(() => {
        globalState.runState = RunState.stop
      })
    }
    result.success(true)
  }

  private handleStop(result: MethodResult): void {
    if (globalState.runState === RunState.start) {
      globalState.runState = RunState.pending
      const resultStub = new ResultStub("handleStop", (runTime: number) => {
        globalState.runTime = runTime
        globalState.runState = RunState.stop
      })
      this.parent.handleStopService(resultStub).catch(() => {
        globalState.runState = RunState.start
      })
    }
    result.success(true)
  }

  private handleGetRunTime(result: MethodResult): void {
    this.parent.handleGetRunTime().then((runTime: number) => {
      globalState.runTime = runTime
    }).finally(() => {
      result.success(globalState.runTime)
    })
  }
}