import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
} from '@ohos/flutter_ohos';
import { publishEvent } from '../utils/Event'
import { formProvider } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import { globalState } from '../GlobalState';
import EntryAbility from '../entryability/EntryAbility';

export default class AppPlugin implements FlutterPlugin, MethodCallHandler {
  private parent: EntryAbility
  private channel: MethodChannel | undefined

  constructor(entryAbility: EntryAbility) {
    this.parent = entryAbility
  }

  getUniqueClassName(): string {
    return "AppPlugin"
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), "com.follow.clash/app")
    this.channel.setMethodCallHandler(this)
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    if (this.channel != null) {
      this.channel.setMethodCallHandler(null)
    }
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    if (call.method === "moveTaskToBack") {
      this.parent.handleMoveTaskToBack(result)
    } else if (call.method === "updateExcludeFromRecents") {
      globalState.excludeFromRecent = (call.args as Map<string, boolean>).get('value') as boolean
      result.success(true)
    } else if (call.method === "initShortcuts") {
      result.success(true)
    } else if (call.method === "getPackages") {
      this.parent.handleGetPackages(result)
    } else if (call.method === "getChinaPackageNames") {
      result.success("[]")
    } else if (call.method === "getPackageIcon") {
      result.success("")
    } else if (call.method === "tip") {
      result.success(true)
    } else if (call.method === "startBackgroundRunning") {
      if (globalState.excludeFromRecent && !globalState.excludeState) {
        const want: Want = {
          bundleName: this.parent.context.applicationInfo.name,
          abilityName: 'FormExtAbility',
          parameters: {
            'ohos.extra.param.key.form_dimension': 1,
            'ohos.extra.param.key.form_name': '',
            'ohos.extra.param.key.module_name': 'entry'
          },
        }
        try {
          formProvider.openFormManager(want)
        } catch (err) {
          console.log(`Call openFormManager failed <= ${err.message ?? err}`)
        }
      }
      publishEvent('SERVICE_START', '')
      result.success(true)
    } else if (call.method === "stopBackgroundRunning") {
      publishEvent('SERVICE_STOP', '')
      result.success(true)
    } else {
      result.notImplemented()
    }
  }
}
