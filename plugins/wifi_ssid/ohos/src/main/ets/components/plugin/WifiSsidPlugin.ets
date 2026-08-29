import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
} from '@ohos/flutter_ohos';
import { wifiManager } from '@kit.ConnectivityKit';

/** WifiSsidPlugin **/
export default class WifiSsidPlugin implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;

  constructor() {
  }

  getUniqueClassName(): string {
    return "WifiSsidPlugin"
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), "wifi_ssid");
    this.channel.setMethodCallHandler(this)
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    if (this.channel != null) {
      this.channel.setMethodCallHandler(null)
    }
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    if (call.method == "getSsid") {
      try {
        const isConnected: Boolean = wifiManager.isConnected()
        if (wifiManager.isConnected()) {
          result.success(wifiManager.getLinkedInfoSync().ssid)
        } else {
          result.success(null)
        }
      } catch (error) {
        console.error("get connected status error: ", error)
        result.success(null)
      }
    } else if (call.method == "checkPermission") {
      result.success(0)
    } else if (call.method == "requestPermission") {
      result.success(0)
    } else {
      result.notImplemented()
    }
  }
}