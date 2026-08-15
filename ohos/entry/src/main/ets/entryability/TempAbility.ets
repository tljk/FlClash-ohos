import { UIAbility, Want, common, bundleManager } from '@kit.AbilityKit';
import { vpnExtension } from '@kit.NetworkKit';
import { commonEventManager } from "@kit.BasicServicesKit"
import { rpc } from '@kit.IPCKit';
import NotificationManager from '../managers/NotificationManager';

export default class TempAbility extends UIAbility {
  private subscriber: commonEventManager.CommonEventSubscriber
  private notificationManager: NotificationManager | undefined
  
  constructor() {
    super()
    this.subscriber = commonEventManager.createSubscriberSync({
      events: ['SERVICE_STOP']
    } as commonEventManager.CommonEventSubscribeInfo)
  }

  onCreate(): void {
    this.notificationManager = new NotificationManager(this.context)
    this.notificationManager?.subscribe()
    
    commonEventManager.subscribeToEvent(this.subscriber, (commonEventData: commonEventManager.CommonEventData) => {
      this.context.terminateSelf()
    })

    const want: Want = {
      bundleName: this.context.applicationInfo.name,
      abilityName: 'VpnExtAbility',
    }
    vpnExtension.startVpnExtensionAbility(want).then(() => {
      this.context.connectServiceExtensionAbility(want, {
        onConnect: (elementName: bundleManager.ElementName, remote: rpc.RemoteObject) => {},
        onDisconnect: (elementName: bundleManager.ElementName) => {
          this.context.terminateSelf()
        },
        onFailed: (code: number) => {
          this.context.terminateSelf()
        },
      } as common.ConnectOptions)
    })
  }

  onDestroy(): void {
    this.notificationManager?.unsubscribe()
    commonEventManager.unsubscribe(this.subscriber)
  }
}
