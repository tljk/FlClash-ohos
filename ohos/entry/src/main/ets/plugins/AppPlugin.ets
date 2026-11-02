import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
} from '@ohos/flutter_ohos'
import { publishEvent } from '../utils/Event'
import { openFormManager } from '../utils/Form'
import { globalState } from '../GlobalState'
import EntryAbility from '../entryability/EntryAbility'

export default class AppPlugin implements FlutterPlugin, MethodCallHandler {
  private parent: EntryAbility
  private channel: MethodChannel | undefined

  constructor(entryAbility: EntryAbility) {
    this.parent = entryAbility
  }

  getUniqueClassName(): string {
    return 'AppPlugin'
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), 'com.follow.clash/app')
    this.channel.setMethodCallHandler(this)
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    if (this.channel != null) {
      this.channel.setMethodCallHandler(null)
    }
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case 'moveTaskToBack':
        this.parent.handleMoveTaskToBack(result)
        break
      case 'updateExcludeFromRecents':
        globalState.excludeFromRecent = (call.args as Map<string, boolean>).get('value') as boolean
        result.success(true)
        break
      case 'initShortcuts':
        result.success(true)
        break
      case 'getPackages':
        this.parent.handleGetPackages(result)
        break
      case 'getChinaPackageNames':
        result.success('[]')
        break
      case 'getPackageIcon':
        result.success('')
        break
      case 'tip':
        result.success(true)
        break
      case 'didCrashOnPreviousExecution':
        result.success(this.parent.didCrashOnPreviousExecution())
        break
      case 'setBackgroundRunning':
        const running = (call.args as Map<string, boolean>).get('value') as boolean
        if (running) {
          if (globalState.excludeFromRecent && !globalState.excludeState) {
            openFormManager(this.parent.context.applicationInfo.name)
          }
          publishEvent('SERVICE_START', '')
        } else {
          publishEvent('SERVICE_STOP', '')
        }
        result.success(true)
        break
      default:
        result.notImplemented()
    }
  }
}
