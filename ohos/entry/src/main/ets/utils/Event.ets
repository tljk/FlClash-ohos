import { commonEventManager } from '@kit.BasicServicesKit';

export function publishEvent(event: string, data: string): Promise<void> {
  return new Promise<void>((resolve, reject) => {
    commonEventManager.publish(event, { data: data }, (err: Error) => {
      if (err) {
        reject(err)
      } else {
        resolve()
      }
    })
  })
}