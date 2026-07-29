
import { FlutterAbility, FlutterEngine, MethodResult } from '@ohos/flutter_ohos';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';
import { common, Want, wantAgent, WantAgent, bundleManager } from '@kit.AbilityKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit'
import { RPCType } from '../extensionAbility/VPNExtensionAbility';
import { VpnOptions } from '../models/State';
import { rpc } from '@kit.IPCKit';
import { vpnExtension } from '@kit.NetworkKit';
import { ChunkedSender, ChunkedReader } from '../utils/Rpc';
import ServicePlugin from '../plugins/ServicePlugin';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import AppPlugin from '../plugins/AppPlugin';

export class CallbackStub extends rpc.RemoteObject {
  private onResult: (data: string) => void | undefined
  private reader: ChunkedReader = new ChunkedReader()
  constructor(descriptor: string, onResult: (data: string) => void) {
    super(descriptor)
    this.onResult = onResult
  }

  onRemoteMessageRequest(code: number, send: rpc.MessageSequence, reply: rpc.MessageSequence, option: rpc.MessageOption): boolean | Promise<boolean> {
    const data = this.reader.read(send)
    if (data !== null) this.onResult(data)
    return true
  }
}

export class ResultStub extends rpc.RemoteObject {
  private onResult: (data: number) => void | undefined
  constructor(descriptor: string, onResult: (data: number) => void) {
    super(descriptor)
    this.onResult = onResult
  }

  onRemoteMessageRequest(code: number, send: rpc.MessageSequence, reply: rpc.MessageSequence, option: rpc.MessageOption): boolean | Promise<boolean> {
    const data = send.readLong()
    this.onResult(data)
    return true
  }
}

export default class EntryAbility extends FlutterAbility {
  private connectId: number | undefined
  private remote: rpc.RemoteObject | undefined
  private sender: ChunkedSender = new ChunkedSender()

  configureFlutterEngine(flutterEngine: FlutterEngine): void {
    super.configureFlutterEngine(flutterEngine)
    flutterEngine.getPlugins()?.add(new AppPlugin(this))
    flutterEngine.getPlugins()?.add(new ServicePlugin(this))
    GeneratedPluginRegistrant.registerWith(flutterEngine)
  }

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    super.onCreate(want, launchParam)
  }

  onDestroy(): void {
    super.onDestroy()
  }

  private async connect(): Promise<void> {
    if (!this.remote) {
      const bundleInfo = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT)
      const want: Want = {
        bundleName: bundleInfo.name,
        abilityName: 'VPNExtensionAbility',
      }
      return vpnExtension.startVpnExtensionAbility(want).then(() => {
        const getProxy = (want: Want, context: common.UIAbilityContext): Promise<rpc.RemoteObject> => {
          return new Promise((resolve, reject) => {
            const options: common.ConnectOptions = {
              onConnect: (elementName: bundleManager.ElementName, remote: rpc.RemoteObject) => { resolve(remote) },
              onDisconnect: (elementName: bundleManager.ElementName) => { this.remote = undefined },
              onFailed: (code: number) => { reject(new Error(`connectServiceExtensionAbility failed: ${code}`)) },
            }
            this.connectId = context.connectServiceExtensionAbility(want, options)
          })
        }
        return getProxy(want, this.context).then((remote: rpc.RemoteObject) => { this.remote = remote })
      })
    } else {
      return Promise.resolve()
    }
  }

  private async disconnect(): Promise<void> {
    if (this.remote && this.connectId) {
      return this.context.disconnectServiceExtensionAbility(this.connectId).then(() => {
        this.remote = undefined
        const bundleInfo = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT)
        const want: Want = {
          bundleName: bundleInfo.name,
          abilityName: 'VPNExtensionAbility',
        }
        return vpnExtension.stopVpnExtensionAbility(want)
      })
    } else {
      return Promise.resolve()
    }
  }

  async handleMoveTaskToBack(result: MethodResult): Promise<void> {
    return this.context.moveAbilityToBackground().finally(() => {
      result.success(true)
    })
  }

  async startContinuousTask(): Promise<void> {
    const bundleInfo = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_HAP_MODULE | bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_ABILITY)
    const wantAgentInfo: wantAgent.WantAgentInfo = {
      wants: [{
        bundleName: bundleInfo.name,
        abilityName: 'EntryAbility',
      }],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: 0,
      actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    }
    return wantAgent.getWantAgent(wantAgentInfo).then((wantAgentObj: WantAgent) => {
      backgroundTaskManager.on("continuousTaskCancel", (cancelInfo: backgroundTaskManager.ContinuousTaskCancelInfo) => { setTimeout(() => this.startContinuousTask(), 1000) })
      return backgroundTaskManager.startBackgroundRunning(this.context, backgroundTaskManager.BackgroundMode.TASK_KEEPING, wantAgentObj)
    })
  }

  async stopContinuousTask(): Promise<void> {
    backgroundTaskManager.off("continuousTaskCancel")
    return backgroundTaskManager.stopBackgroundRunning(this.context)
  }

  async handleInit(callbackStub: CallbackStub): Promise<rpc.RequestResult> {
    await this.connect()
    if (this.remote) {
      const options = new rpc.MessageOption()
      const send = rpc.MessageSequence.create()
      const reply = rpc.MessageSequence.create()
      options.setAsync(true)
      send.writeRemoteObject(callbackStub)
      return this.remote.sendMessageRequest(RPCType.setEventListener, send, reply, options).finally(() => {
        send.reclaim()
        reply.reclaim()
      })
    } else {
      return Promise.reject(new Error('failed to connect to VPN extension ability'))
    }
  }

  async handleShutdown(): Promise<void> {
    return this.disconnect()
  }

  async handleInvokeAction(data: string, callbackStub: CallbackStub): Promise<rpc.RequestResult> {
    await this.connect()
    if (this.remote) {
      return this.sender.send(this.remote, RPCType.invokeAction, data, (send: rpc.MessageSequence) => {
        send.writeRemoteObject(callbackStub)
      })
    } else {
      return Promise.reject(new Error('failed to connect to VPN extension ability'))
    }
  }

  async handleStartService(vpnOptions: VpnOptions, runTime: number, resultStub: ResultStub): Promise<rpc.RequestResult> {
    await this.connect()
    if (this.remote) {
      return this.sender.send(this.remote, RPCType.startService, JSON.stringify(vpnOptions), (send: rpc.MessageSequence) => {
        send.writeLong(runTime)
        send.writeRemoteObject(resultStub)
      })
    } else {
      return Promise.reject(new Error('failed to connect to VPN extension ability'))
    }
  }

  async handleStopService(resultStub: ResultStub): Promise<rpc.RequestResult> {
    await this.connect()
    if (this.remote) {
      const options = new rpc.MessageOption()
      const send = rpc.MessageSequence.create()
      const reply = rpc.MessageSequence.create()
      options.setAsync(false)
      send.writeRemoteObject(resultStub)
      return this.remote.sendMessageRequest(RPCType.stopService, send, reply, options).finally(() => {
        send.reclaim()
        reply.reclaim()
      })
    } else {
      return Promise.reject(new Error('failed to connect to VPN extension ability'))
    }
  }

  async handleGetRunTime(): Promise<number> {
    await this.connect()
    if (this.remote) {
      const options = new rpc.MessageOption()
      const send = rpc.MessageSequence.create()
      const reply = rpc.MessageSequence.create()
      options.setAsync(false)
      return this.remote.sendMessageRequest(RPCType.getRunTime, send, reply, options).then((requestResult: rpc.RequestResult) => {
        return requestResult.reply.readLong()
      }).finally(() => {
        send.reclaim()
        reply.reclaim()
      })
    } else {
      return Promise.reject(new Error('failed to connect to VPN extension ability'))
    }
  }
}
