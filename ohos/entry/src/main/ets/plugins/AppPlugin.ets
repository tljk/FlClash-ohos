import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
} from '@ohos/flutter_ohos';
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
      result.success(true)
    } else if (call.method === "initShortcuts") {
      result.success(true)
    } else if (call.method === "getPackages") {
      result.success("[]")
    } else if (call.method === "getChinaPackageNames") {
      result.success("[]")
    } else if (call.method === "getPackageIcon") {
      result.success("")
    } else if (call.method === "tip") {
      result.success(true)
    } else {
      result.notImplemented()
    }
  }
}
