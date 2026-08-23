import { UIAbility, Want, common, bundleManager } from '@kit.AbilityKit';
import { vpnExtension } from '@kit.NetworkKit';
import { commonEventManager } from "@kit.BasicServicesKit"
import { rpc } from '@kit.IPCKit';
import { deviceInfo } from '@kit.BasicServicesKit'
import { VpnOptions } from '../models/State'
import { ChunkedSender } from '../utils/Rpc';
import { Lock } from '../utils/Lock'
import { RPCType } from '../extensionAbility/VpnExtAbility'
import { CallbackStub, ResultStub } from './EntryAbility';
import { globalState, RunState } from '../GlobalState';
import NotificationManager from '../managers/NotificationManager';

interface Connection {
  id: number
  remote: rpc.RemoteObject
}

export default class TempAbility extends UIAbility {
  private sender: ChunkedSender = new ChunkedSender()
  private subscriber: commonEventManager.CommonEventSubscriber
  private notificationManager: NotificationManager | undefined
  private connecting: Promise<Connection> | undefined
  private disconnecting: Promise<void> | undefined
  private unlock: (() => void) | undefined
  private get lock(): Lock {
    if (!AppStorage.has('ipc_lock')) AppStorage.setOrCreate('ipc_lock', new Lock())
    return AppStorage.get('ipc_lock') as Lock
  }

  constructor() {
    super()
    this.subscriber = commonEventManager.createSubscriberSync({
      events: ['SERVICE_STOP', 'SERVICE_YIELD']
    } as commonEventManager.CommonEventSubscribeInfo)
  }

  onCreate(): void {
    if (globalState.runState === RunState.stop || !globalState.excludeFromRecent) {
      this.context.terminateSelf()
    } else {
      this.notificationManager = new NotificationManager(this.context)
      this.notificationManager?.subscribe()
      commonEventManager.subscribeToEvent(this.subscriber, (commonEventData: commonEventManager.CommonEventData) => {
        if (commonEventData.event === 'SERVICE_YIELD') {
          this.disconnect()
        } else if (commonEventData.event === 'SERVICE_STOP') {
          this.context.terminateSelf()
        }
      })

      if (!this.connecting) this.connecting = this.connect()
    }
  }

  onDestroy(): void {
    this.disconnect()
    this.notificationManager?.unsubscribe()
    commonEventManager.unsubscribe(this.subscriber)
  }

  private connect(setup?: boolean): Promise<Connection> {
    return (this.disconnecting ?? Promise.resolve()).then(() => {
      return this.lock.acquire(this.context.abilityInfo.name).then((unlock: () => void) => {
        this.unlock = unlock
        const want: Want = {
          bundleName: this.context.applicationInfo.name,
          abilityName: 'VpnExtAbility',
        }
        return vpnExtension.startVpnExtensionAbility(want).then(() => {
          return this.connectService(want, this.context, setup)
        }).catch((err: Error) => {
          if (this.unlock) {
            this.unlock()
            this.unlock = undefined
          }
          this.connecting = undefined
          this.context.terminateSelf()
          throw err
        })
      })
    })
  }

  private connectService(want: Want, context: common.UIAbilityContext, setup?: boolean): Promise<Connection> {
    return new Promise((resolve, reject) => {
      let id = -1
      id = this.context.connectServiceExtensionAbility(want, {
        onConnect: (elementName: bundleManager.ElementName, remote: rpc.RemoteObject) => {
          if (setup && globalState.state.setupParams && globalState.runState !== RunState.pending) {
            globalState.runState = RunState.stop
            this.handleQuickSetup(remote).then(() => {
              this.handleStart(remote)
            })
          }
          resolve({id, remote})
        },
        onDisconnect: (elementName: bundleManager.ElementName) => {
          this.connecting = undefined
          if (this.disconnecting) {
            this.disconnecting.finally(() => {
              if (this.unlock) {
                this.unlock()
                this.unlock = undefined
              }
              this.disconnecting = undefined
              this.connecting = this.connect()
            })
          } else {
            if (this.unlock) {
              this.unlock()
              this.unlock = undefined
            }
            if (globalState.runState === RunState.start) this.connecting = this.connect(true)
          }
        },
        onFailed: (code: number) => {
          this.connecting = undefined
          reject(new Error(`connectServiceExtensionAbility failed: ${code}`))
        },
      } as common.ConnectOptions)
    })
  }

  private disconnect(): Promise<void> {
    if (!this.unlock) this.lock.revoke(this.context.abilityInfo.name)

    if (this.connecting) {
      return this.connecting.then((connection: Connection) => {
        if (!this.disconnecting) this.disconnecting = this.context.disconnectServiceExtensionAbility(connection.id)
        return this.disconnecting
      })
    } else {
      if (this.unlock) {
        this.unlock()
        this.unlock = undefined
      }
      return Promise.resolve()
    }
  }

  private handleQuickSetup(remote: rpc.RemoteObject): Promise<rpc.RequestResult> {
    const initParams = { 'home-dir': this.context.getApplicationContext().filesDir, 'version': deviceInfo.sdkApiVersion } as Record<string, string|number>
    const setupParams = globalState.state.setupParams
    const callbackStub = new CallbackStub("quickSetup", (data: string) => { console.log(`Call quickSetup <= ${data}`) })
    return this.sender.send(remote, RPCType.quickSetup, JSON.stringify(setupParams), (send: rpc.MessageSequence) => {
      send.writeString(JSON.stringify(initParams))
      send.writeRemoteObject(callbackStub)
    })
  }

  private handleStart(remote: rpc.RemoteObject): void {
    if (globalState.runState === RunState.stop) {
      globalState.runState = RunState.pending
      const options = globalState.state?.vpnOptions ?? new VpnOptions()
      const resultStub = new ResultStub("handleStart", (runTime: number) => {
        globalState.runTime = runTime
        globalState.runState = runTime !== 0 ? RunState.start : RunState.stop
      })
      this.sender.send(remote, RPCType.startService, JSON.stringify(options), (send: rpc.MessageSequence) => {
        send.writeLong(globalState.runTime)
        send.writeRemoteObject(resultStub)
      }).catch(() => {
        globalState.runState = RunState.stop
      })
    }
  }
}
