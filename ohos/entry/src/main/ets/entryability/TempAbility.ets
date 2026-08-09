import { UIAbility, Want } from '@kit.AbilityKit';
import { vpnExtension } from '@kit.NetworkKit';
import { commonEventManager } from "@kit.BasicServicesKit"
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

    vpnExtension.startVpnExtensionAbility({
      bundleName: this.context.applicationInfo.name,
      abilityName: 'VpnExtAbility',
    } as Want)
  }

  onDestroy(): void {
    this.notificationManager?.unsubscribe()
    commonEventManager.unsubscribe(this.subscriber)
  }
}
