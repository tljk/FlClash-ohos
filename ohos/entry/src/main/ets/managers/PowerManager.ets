import { commonEventManager } from "@kit.BasicServicesKit"

export default class PowerManager {
  private subscriber: commonEventManager.CommonEventSubscriber

  constructor() {
    const subscribeInfo: commonEventManager.CommonEventSubscribeInfo = {
      events: [commonEventManager.Support.COMMON_EVENT_DEVICE_IDLE_MODE_CHANGED]
    }
    this.subscriber = commonEventManager.createSubscriberSync(subscribeInfo)
  }

  async subscribe(callback: (idle: boolean) => void): Promise<void> {
    return new Promise((resolve, reject) => {
      commonEventManager.subscribe(this.subscriber, (err: Error, commonEventData: commonEventManager.CommonEventData|void) => {
        if (err || !commonEventData) {
          reject(err)
        } else {
          callback(commonEventData.parameters?.sleeping)
          resolve()
        }
      })
    })
  }

  async unsubscribe(): Promise<void> {
    commonEventManager.unsubscribe(this.subscriber)
    return Promise.resolve()
  }
}