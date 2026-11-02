import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
} from '@ohos/flutter_ohos'
import { CallbackStub, ResultStub } from '../entryability/EntryAbility'
import { State, VpnOptions } from '../models/State'
import { publishEvent } from '../utils/Event'
import { globalState, RunState } from '../GlobalState'
import EntryAbility from '../entryability/EntryAbility'

export default class ServicePlugin implements FlutterPlugin, MethodCallHandler {
  private parent: EntryAbility
  private channel: MethodChannel | undefined

  constructor(entryAbility: EntryAbility) {
    this.parent = entryAbility
  }

  getUniqueClassName(): string {
    return 'ServicePlugin'
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), 'com.follow.clash/service')
    this.channel.setMethodCallHandler(this)
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    if (this.channel != null) {
      this.channel.setMethodCallHandler(null)
    }
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case 'init':
        this.initialize(result)
        break
      case 'shutdown':
        this.shutdown(result)
        break
      case 'invokeMethod':
        this.invokeMethod(call, result)
        break
      case 'getRunTime':
        this.getRunTime(result)
        break
      case 'syncState':
        this.syncState(call, result)
        break
      case 'start':
        this.start(result)
        break
      case 'stop':
        this.stop(result)
        break
      default:
        result.notImplemented()
    }
  }

  private initialize(result: MethodResult): void {
    const callbackStub = new CallbackStub('setEventListener', (data: string | Uint8Array) => { this.channel?.invokeMethod('event', data) })
    this.parent.handleInit(callbackStub).then(() => {
      result.success('')
    }).catch((err: Error) => {
      result.success(err.message ?? `${err}`)
    })
    this.parent.setOnDisconnected((message: string) => {
      globalState.runTime = 0
      globalState.runState = RunState.stop
      this.channel?.invokeMethod('crash', message)
      publishEvent('SERVICE_STOP', '')
    })
  }

  private shutdown(result: MethodResult): void {
    this.parent.handleShutdown().finally(() => {
      globalState.runTime = 0
      globalState.runState = RunState.stop
      result.success(true)
    })
  }

  private syncState(call: MethodCall, result: MethodResult): void {
    globalState.state = JSON.parse(call.args) as State
    globalState.runState = globalState.runTime === 0 ? RunState.stop : RunState.start
    result.success('')
  }

  private invokeMethod(call: MethodCall, result: MethodResult): void {
    const callbackStub = new CallbackStub('invokeMethod', (data: string | Uint8Array) => { result.success(data) })
    this.parent.handleInvokeMethod(call.args, callbackStub)
  }

  private start(result: MethodResult): void {
    if (globalState.runState === RunState.stop) {
      globalState.runState = RunState.pending
      const options = globalState.state?.vpnOptions ?? new VpnOptions()
      const resultStub = new ResultStub('handleStart', (runTime: number) => {
        globalState.runTime = runTime
        globalState.runState = runTime !== 0 ? RunState.start : RunState.stop
      })
      this.parent.handleStartService(options, globalState.runTime, resultStub).catch(() => {
        globalState.runState = RunState.stop
      })
    }
    result.success(true)
  }

  private stop(result: MethodResult): void {
    if (globalState.runState === RunState.start) {
      globalState.runState = RunState.pending
      const resultStub = new ResultStub('handleStop', (runTime: number) => {
        globalState.runTime = runTime
        globalState.runState = RunState.stop
      })
      this.parent.handleStopService(resultStub).catch(() => {
        globalState.runState = RunState.start
      })
    }
    result.success(true)
  }

  private getRunTime(result: MethodResult): void {
    this.parent.handleGetRunTime().then((runTime: number) => {
      globalState.runTime = runTime
    }).finally(() => {
      result.success(globalState.runTime)
    })
  }
}