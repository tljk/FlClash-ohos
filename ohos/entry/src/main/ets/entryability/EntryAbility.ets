
import { FlutterAbility, FlutterEngine, MethodResult } from '@ohos/flutter_ohos';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';
import { common, Want, bundleManager } from '@kit.AbilityKit';
import { antifraudPicker } from '@kit.DeviceSecurityKit';
import { RPCType } from '../extensionAbility/VpnExtAbility';
import { VpnOptions } from '../models/State';
import { Bundle } from '../models/Bundle';
import { rpc } from '@kit.IPCKit';
import { vpnExtension } from '@kit.NetworkKit';
import { ChunkedSender, ChunkedReader } from '../utils/Rpc';
import { Lock } from '../utils/Lock'
import ServicePlugin from '../plugins/ServicePlugin';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import AppPlugin from '../plugins/AppPlugin';
import NotificationManager from '../managers/NotificationManager';

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
  private sender: ChunkedSender = new ChunkedSender()
  private notificationManager: NotificationManager | undefined
  private connecting: Promise<rpc.RemoteObject> | undefined
  private unlock: (() => void) | undefined
  private get lock(): Lock {
    if (!AppStorage.has('ipc_lock')) AppStorage.setOrCreate('ipc_lock', new Lock())
    return AppStorage.get('ipc_lock') as Lock
  }
  
  configureFlutterEngine(flutterEngine: FlutterEngine): void {
    super.configureFlutterEngine(flutterEngine)
    flutterEngine.getPlugins()?.add(new AppPlugin(this))
    flutterEngine.getPlugins()?.add(new ServicePlugin(this))
    GeneratedPluginRegistrant.registerWith(flutterEngine)
  }

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    super.onCreate(want, launchParam)
    this.notificationManager = new NotificationManager(this.context)
    this.notificationManager?.subscribe()
  }

  onDestroy(): void {
    super.onDestroy()
    this.connecting = undefined
    this.notificationManager?.unsubscribe()
    if (this.unlock && this.connectId) {
      this.context.disconnectServiceExtensionAbility(this.connectId).then(() => {
        if (this.unlock) {
          this.unlock()
          this.unlock = undefined
        }
      })
    } else {
      this.lock.revoke(this.context.abilityInfo.name)
    }
  }

  private connect(): Promise<rpc.RemoteObject> {
    const want: Want = {
      bundleName: this.context.applicationInfo.name,
      abilityName: 'VpnExtAbility',
    }
    return vpnExtension.startVpnExtensionAbility(want).then(() => {
      return this.lock.acquire(this.context.abilityInfo.name).then((unlock: () => void) => {
        const getProxy = (want: Want, context: common.UIAbilityContext, unlock: () => void): Promise<rpc.RemoteObject> => {
          return new Promise((resolve, reject) => {
            this.connectId = context.connectServiceExtensionAbility(want, {
              onConnect: (elementName: bundleManager.ElementName, remote: rpc.RemoteObject) => {
                this.unlock = unlock
                resolve(remote)
              },
              onDisconnect: (elementName: bundleManager.ElementName) => {
                unlock()
                this.unlock = undefined
                this.connecting = undefined
                this.connectId = undefined
              },
              onFailed: (code: number) => {
                unlock()
                this.connecting = undefined
                this.connectId = undefined
                reject(new Error(`connectServiceExtensionAbility failed: ${code}`))
              },
            } as common.ConnectOptions)
          })
        }
        return getProxy(want, this.context, unlock)
      })
    })
  }

  private ensureConnected(): Promise<rpc.RemoteObject> {
    if (!this.connecting) this.connecting = this.connect()
    return this.connecting
  }

  private disconnect(): Promise<void> {
    this.connecting = undefined
    if (this.unlock && this.connectId) {
      return this.context.disconnectServiceExtensionAbility(this.connectId).then(() => {
        if (this.unlock) {
          this.unlock()
          this.unlock = undefined
        }
        const want: Want = {
          bundleName: this.context.applicationInfo.name,
          abilityName: 'VpnExtAbility',
        }
        return vpnExtension.stopVpnExtensionAbility(want)
      })
    } else {
      this.lock.revoke(this.context.abilityInfo.name)
      return Promise.resolve()
    }
  }

  handleMoveTaskToBack(result: MethodResult): Promise<void> {
    return this.context.moveAbilityToBackground().finally(() => {
      result.success(true)
    })
  }

  handleGetPackages(result: MethodResult): Promise<void> {
    return antifraudPicker.selectFraudApp(this.context).then((antifraudAppResult: antifraudPicker.AntifraudAppResult) => {
      const bundleList: Bundle[] = []
      for (const singleAntifraudAppInfo of antifraudAppResult.appInfo) {
        bundleList.push({ packageName: singleAntifraudAppInfo.bundleName, label: singleAntifraudAppInfo.label, system: false, internet: true, lastUpdateTime: 0 } as Bundle)
      }
      result.success(JSON.stringify(bundleList))
    }).catch((err: Error) => {
      console.log(`Call getPackages failed <= ${err.message ?? err}`)
      result.success('[]')
    })
  }

  handleInit(callbackStub: CallbackStub): Promise<rpc.RequestResult> {
    return this.ensureConnected().then((remote: rpc.RemoteObject) => {
      const options = new rpc.MessageOption()
      const send = rpc.MessageSequence.create()
      const reply = rpc.MessageSequence.create()
      options.setAsync(true)
      send.writeRemoteObject(callbackStub)
      return remote.sendMessageRequest(RPCType.setEventListener, send, reply, options).finally(() => {
        send.reclaim()
        reply.reclaim()
      })
    })
  }

  handleShutdown(): Promise<void> {
    return this.disconnect()
  }

  handleInvokeAction(data: string, callbackStub: CallbackStub): Promise<rpc.RequestResult> {
    return this.ensureConnected().then((remote: rpc.RemoteObject) => {
      return this.sender.send(remote, RPCType.invokeAction, data, (send: rpc.MessageSequence) => {
        send.writeRemoteObject(callbackStub)
      })
    })
  }

  handleStartService(vpnOptions: VpnOptions, runTime: number, resultStub: ResultStub): Promise<rpc.RequestResult> {
    return this.ensureConnected().then((remote: rpc.RemoteObject) => {
      return this.sender.send(remote, RPCType.startService, JSON.stringify(vpnOptions), (send: rpc.MessageSequence) => {
        send.writeLong(runTime)
        send.writeRemoteObject(resultStub)
      })
    })
  }

  handleStopService(resultStub: ResultStub): Promise<rpc.RequestResult> {
    return this.ensureConnected().then((remote: rpc.RemoteObject) => {
      const options = new rpc.MessageOption()
      const send = rpc.MessageSequence.create()
      const reply = rpc.MessageSequence.create()
      options.setAsync(false)
      send.writeRemoteObject(resultStub)
      return remote.sendMessageRequest(RPCType.stopService, send, reply, options).finally(() => {
        send.reclaim()
        reply.reclaim()
      })
    })
  }

  handleGetRunTime(): Promise<number> {
    return this.ensureConnected().then((remote: rpc.RemoteObject) => {
      const options = new rpc.MessageOption()
      const send = rpc.MessageSequence.create()
      const reply = rpc.MessageSequence.create()
      options.setAsync(false)
      return remote.sendMessageRequest(RPCType.getRunTime, send, reply, options).then((requestResult: rpc.RequestResult) => {
        return requestResult.reply.readLong()
      }).finally(() => {
        send.reclaim()
        reply.reclaim()
      })
    })
  }
}
