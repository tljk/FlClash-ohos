
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
import ServicePlugin from '../plugins/ServicePlugin';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import AppPlugin from '../plugins/AppPlugin';
import NotificationManager from '../managers/NotificationManager';

interface Connection {
  id: number
  remote: rpc.RemoteObject
}

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
  private sender: ChunkedSender = new ChunkedSender()
  private notificationManager: NotificationManager | undefined
  private connecting: Promise<Connection> | undefined
  private disconnecting: Promise<void> | undefined
  private onDisconnected: ((message: string) => void) | undefined
  
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
    this.disconnect()
    this.notificationManager?.unsubscribe()
  }

  private connect(): Promise<Connection> {
    return (this.disconnecting ?? Promise.resolve()).then(() => {
      const want: Want = {
        bundleName: this.context.applicationInfo.name,
        abilityName: 'VpnExtAbility',
      }
      return vpnExtension.startVpnExtensionAbility(want).then(() => {
        const getProxy = (want: Want, context: common.UIAbilityContext): Promise<Connection> => {
          return new Promise((resolve, reject) => {
            let id = -1
            id = context.connectServiceExtensionAbility(want, {
              onConnect: (elementName: bundleManager.ElementName, remote: rpc.RemoteObject) => {
                resolve({id, remote})
              },
              onDisconnect: (elementName: bundleManager.ElementName) => {
                this.connecting = undefined
                if (this.disconnecting) {
                  this.disconnecting.finally(() => {
                    this.disconnecting = undefined
                  })
                } else {
                  this.onDisconnected?.(`${elementName.abilityName} disconnected unexpectedly`)
                }
              },
              onFailed: (code: number) => {
                this.connecting = undefined
                reject(new Error(`connectServiceExtensionAbility failed: ${code}`))
              },
            } as common.ConnectOptions)
          })
        }
        return getProxy(want, this.context)
      })
    })
  }

  private ensureConnected(): Promise<rpc.RemoteObject> {
    if (!this.connecting) this.connecting = this.connect()
    return this.connecting.then((connection: Connection) => connection.remote)
  }

  private disconnect(): Promise<void> {
    if (this.connecting) {
      return this.connecting.then((connection: Connection) => {
        if (!this.disconnecting) this.disconnecting = this.context.disconnectServiceExtensionAbility(connection.id)
        return this.disconnecting
      })
    } else {
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

  setOnDisconnected(callback: (message: string) => void): void {
    this.onDisconnected = callback
  }
}
