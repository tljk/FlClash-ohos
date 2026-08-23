import { common, wantAgent, WantAgent } from '@kit.AbilityKit'
import { backgroundTaskManager } from '@kit.BackgroundTasksKit'
import { commonEventManager } from "@kit.BasicServicesKit"
import { Lock } from '../utils/Lock'
import { globalState, RunState } from '../GlobalState';

export default class NotificationManager {
  private context: common.UIAbilityContext
  private subscriber: commonEventManager.CommonEventSubscriber
  private unlock: (() => void) | undefined
  private get lock(): Lock {
    if (!AppStorage.has('notification_lock')) AppStorage.setOrCreate('notification_lock', new Lock())
    return AppStorage.get('notification_lock') as Lock
  }

  constructor(context: common.UIAbilityContext) {
    this.context = context
    this.subscriber = commonEventManager.createSubscriberSync({
      events: ['SERVICE_START', 'SERVICE_STOP']
    } as commonEventManager.CommonEventSubscribeInfo)
  }

  subscribe(): Promise<void> {
    return this.lock.acquire(this.context.abilityInfo.name).then((unlock: () => void) => {
      this.unlock = unlock
      if (globalState.runState === RunState.start) this.startContinuousTask()
      return commonEventManager.subscribeToEvent(this.subscriber, (commonEventData: commonEventManager.CommonEventData) => {
        if (commonEventData.event === 'SERVICE_START') {
          this.startContinuousTask()
        } else if (commonEventData.event === 'SERVICE_STOP') {
          this.stopContinuousTask()
        }
      }).catch((err: Error) => {
        if (this.unlock) {
          this.unlock()
          this.unlock = undefined
        }
        throw err
      })
    })    
  }

  unsubscribe(): Promise<void> {
    commonEventManager.unsubscribe(this.subscriber)
    if (this.unlock) {
      this.unlock()
      this.unlock = undefined
    } else {
      this.lock.revoke(this.context.abilityInfo.name)
    }
    return Promise.resolve()
  }

  private startContinuousTask(): Promise<void> {
    const wantAgentInfo: wantAgent.WantAgentInfo = {
      wants: [{
        bundleName: this.context.applicationInfo.name,
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

  private stopContinuousTask(): Promise<void> {
    backgroundTaskManager.off("continuousTaskCancel")
    return backgroundTaskManager.stopBackgroundRunning(this.context)
  }
}