import { commonEventManager } from "@kit.BasicServicesKit"

export default class PowerManager {
  private subscriber: commonEventManager.CommonEventSubscriber

  constructor() {
    this.subscriber = commonEventManager.createSubscriberSync({
      events: [commonEventManager.Support.COMMON_EVENT_DEVICE_IDLE_MODE_CHANGED]
    } as commonEventManager.CommonEventSubscribeInfo)
  }

  subscribe(callback: (idle: boolean) => void): Promise<void> {
    return commonEventManager.subscribeToEvent(this.subscriber, (commonEventData: commonEventManager.CommonEventData) => {
      callback(commonEventData.parameters?.sleeping)
    })
  }

  unsubscribe(): Promise<void> {
    commonEventManager.unsubscribe(this.subscriber)
    return Promise.resolve()
  }
}