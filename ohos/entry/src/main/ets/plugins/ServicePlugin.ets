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
import EntryAbility from '../entryability/EntryAbility';

export enum RunState {
  start, pending, stop
}

export default class ServicePlugin implements FlutterPlugin, MethodCallHandler {
  private parent: EntryAbility
  private channel: MethodChannel | undefined
  private state: State | undefined
  private get runTime(): number {
    if (!AppStorage.has('run_time')) AppStorage.setOrCreate('run_time', 0)
    return AppStorage.get('run_time') as number
  }
  private set runTime(timestamp: number) {
    AppStorage.setOrCreate('run_time', timestamp)
  }
  private get runState(): RunState {
    if (!AppStorage.has('run_state')) AppStorage.setOrCreate('run_state', RunState.stop)
    return AppStorage.get('run_state') as RunState
  }
  private set runState(state: RunState) {
    AppStorage.setOrCreate('run_state', state)
  }
  private get excludeFromRecent(): boolean {
    if (!AppStorage.has('exclude_recent')) AppStorage.setOrCreate('exclude_recent', false)
    return AppStorage.get<boolean>('exclude_recent') as boolean
  }

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
  }

  private handleShutdown(result: MethodResult): void {
    this.parent.handleShutdown().finally(() => {
      this.runTime = 0
      this.runState = RunState.stop
      result.success(true)
    })
  }

  private handleSyncState(call: MethodCall, result: MethodResult): void {
    this.state = JSON.parse(call.args)
    this.runState = this.runTime === 0 ? RunState.stop : RunState.start
    result.success("")
  }

  private handleInvokeAction(call: MethodCall, result: MethodResult): void {
    const callbackStub = new CallbackStub("invokeAction", (data: string) => { result.success(data) })
    this.parent.handleInvokeAction(call.args, callbackStub)
  }

  private handleStart(result: MethodResult): void {
    if (this.runState === RunState.stop) {
      this.runState = RunState.pending
      const options = this.state?.vpnOptions ?? new VpnOptions()
      const resultStub = new ResultStub("handleStart", (runTime: number) => {
        this.runTime = runTime
        this.runState = runTime !== 0 ? RunState.start : RunState.stop
        if (this.excludeFromRecent) {
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
      this.parent.handleStartService(options, this.runTime, resultStub).catch(() => {
        this.runState = RunState.stop
      })
    }
    result.success(true)
  }

  private handleStop(result: MethodResult): void {
    if (this.runState === RunState.start) {
      this.runState = RunState.pending
      const resultStub = new ResultStub("handleStop", (runTime: number) => {
        this.runTime = runTime
        this.runState = RunState.stop
      })
      this.parent.handleStopService(resultStub).catch(() => {
        this.runState = RunState.start
      })
    }
    result.success(true)
  }

  private handleGetRunTime(result: MethodResult): void {
    this.parent.handleGetRunTime().then((runTime: number) => {
      this.runTime = runTime
    }).finally(() => {
      result.success(this.runTime)
    })
  }
}