import { vpnExtension, VpnExtensionAbility, connection } from '@kit.NetworkKit'
import { Want } from '@kit.AbilityKit'
import { rpc } from '@kit.IPCKit'
import { deviceInfo } from '@kit.BasicServicesKit'
import { util } from '@kit.ArkTS'
import { setEventListener, invokeMethod, startTUN, stopTun, forceGC, updateDns, quickSetup } from 'core'
import { AccessControlMode, VpnOptions } from '../models/State'
import { ChunkedSender, ChunkedReader } from '../utils/Rpc'
import AbilityConstant from '@ohos.app.ability.AbilityConstant'
import NetworkManager from '../managers/NetworkManager'

const IPV4_ADDRESS = '172.19.0.1/30'
const IPV6_ADDRESS = 'fdfe:dcba:9876::1/126'
const DNS = '172.19.0.2'
const DNS6 = 'fdfe:dcba:9876::2'
const NET_ANY = '0.0.0.0'
const NET_ANY6 = '::'

export enum RPCType {
  invokeMethod,
  quickSetup,
  updateNotificationParams,
  startService,
  stopService,
  setEventListener,
  setCrashlytics,
  getRunTime,
}

export class ServiceStub extends rpc.RemoteObject {
  private parent: VpnExtAbility
  private reader: ChunkedReader = new ChunkedReader()

  constructor(descriptor: string, parent: VpnExtAbility) {
    super(descriptor)
    this.parent = parent
  }

  onRemoteMessageRequest(code: number, send: rpc.MessageSequence, reply: rpc.MessageSequence, option: rpc.MessageOption): boolean | Promise<boolean> {
    if (code === RPCType.setEventListener) {
      const remote = send.readRemoteObject() as rpc.RemoteObject
      this.parent.handleSetEventListener(remote)
      return true
    } else if (code === RPCType.invokeMethod) {
      const data = this.reader.read(send)
      if (data === null) return true
      const remote = send.readRemoteObject() as rpc.RemoteObject
      this.parent.handleInvokeMethod(data, remote)
      return true
    } else if (code === RPCType.startService) {
      const raw = this.reader.read(send)
      if (raw === null) return true
      const vpnOptions = JSON.parse(raw) as VpnOptions
      const runTime = send.readLong()
      const remote = send.readRemoteObject() as rpc.RemoteObject
      this.parent.handleStartService(vpnOptions, runTime, remote)
      return true
    } else if (code === RPCType.stopService) {
      const remote = send.readRemoteObject() as rpc.RemoteObject
      this.parent.handleStopService(remote)
      return true
    } else if (code === RPCType.getRunTime) {
      this.parent.handleGetRunTime(reply)
      return true
    } else if (code === RPCType.quickSetup) {
      const setupParams = this.reader.read(send)
      if (setupParams === null) return true
      const initParams = send.readString()
      const remote = send.readRemoteObject() as rpc.RemoteObject
      this.parent.handleQuickSetup(initParams, setupParams, remote)
      return true
    } else if (code === RPCType.updateNotificationParams) {
      return true
    } else if (code === RPCType.setCrashlytics) {
      return true
    } else {
      return false
    }
  }
}

export default class VpnExtAbility extends VpnExtensionAbility {
  private service: ServiceStub | undefined
  private vpnConnection: vpnExtension.VpnConnection | undefined
  private vpnId: string | undefined
  private networkManager: NetworkManager | undefined
  private runTime: number = 0
  private sender: ChunkedSender = new ChunkedSender()

  onCreate(want: Want): void {
    this.vpnConnection = vpnExtension.createVpnConnection(this.context)
    this.networkManager = new NetworkManager()
  }

  onDestroy(): void {
    this.vpnConnection?.destroy()
    this.networkManager?.unsubscribe()
  }

  onConnect(want: Want): rpc.RemoteObject {
    if (!this.service) this.service = new ServiceStub('ServiceStub', this)
    return this.service
  }

  onDisconnect(want: Want): void {
    setEventListener()
  }

  onMemoryLevel(level: AbilityConstant.MemoryLevel): void {
    if (level === AbilityConstant.MemoryLevel.MEMORY_LEVEL_CRITICAL) forceGC()
  }

  private toLinkAddress(cidr: string, family: number): vpnExtension.LinkAddress {
    const parts = cidr.split('/')
    const address: connection.NetAddress = { address: parts[0], family }
    return { address, prefixLength: Number(parts[1]) }
  }

  private toRouteInfo(cidr: string, family: number): vpnExtension.RouteInfo {
    const destination = this.toLinkAddress(cidr, family)
    const gateway: connection.NetAddress = { address: '', family }
    return {
      interface: '',
      destination,
      gateway,
      hasGateway: false,
      isDefaultRoute: destination.prefixLength === 0,
    }
  }

  private toVpnConfig(options: VpnOptions): vpnExtension.VpnConfig {
    const ipv4RouteAddress = options.routeAddress.filter((it) => !it.includes(':'))
    const ipv6RouteAddress = options.routeAddress.filter((it) => it.includes(':'))

    const addresses: vpnExtension.LinkAddress[] = [this.toLinkAddress(IPV4_ADDRESS, 1)]
    const routes: vpnExtension.RouteInfo[] = ipv4RouteAddress.length > 0
      ? ipv4RouteAddress.map((it) => this.toRouteInfo(it, 1))
      : [this.toRouteInfo(`${NET_ANY}/0`, 1)]
    const dnsAddresses: string[] = [DNS]

    if (options.ipv6) {
      addresses.push(this.toLinkAddress(IPV6_ADDRESS, 2))
      routes.push(...(ipv6RouteAddress.length > 0
        ? ipv6RouteAddress.map((it) => this.toRouteInfo(it, 2))
        : [this.toRouteInfo(`${NET_ANY6}/0`, 2)]))
      dnsAddresses.push(DNS6)
    }

    const config: vpnExtension.VpnConfig = {
      addresses,
      routes,
      dnsAddresses,
      mtu: 9000,
      isIPv4Accepted: true,
      isIPv6Accepted: options.ipv6,
      isBlocking: !options.allowBypass,
    }

    const accessControl = options.accessControlProps
    if (accessControl.enable) {
      if (accessControl.mode === AccessControlMode.ACCEPT_SELECTED) {
        config.trustedApplications = [...accessControl.acceptList, this.context.applicationInfo.name]
      } else {
        config.blockedApplications = accessControl.rejectList.filter((it) => it !== this.context.applicationInfo.name)
      }
    }

    return config
  }

  private toTunAddress(options: VpnOptions): string {
    const addresses = [IPV4_ADDRESS]
    if (options.ipv6) {
      addresses.push(IPV6_ADDRESS)
    }
    return addresses.join(',')
  }

  private toTunDns(options: VpnOptions): string {
    if (options.dnsHijacking) {
      return NET_ANY
    }
    const dns = [DNS]
    if (options.ipv6) {
      dns.push(DNS6)
    }
    return dns.join(',')
  }

  private toNetAddress(addr: string): connection.NetAddress {
    const separator = addr.lastIndexOf(':')
    const host = addr.slice(0, separator)
    const port = Number(addr.slice(separator + 1))
    const address = host.startsWith('[') && host.endsWith(']') ? host.slice(1, -1) : host
    const family = address.includes(':') ? 2 : 1
    return { address, family, port }
  }

  private protect(socketFd: number): Promise<void> {
    return this.vpnConnection?.protect(socketFd).catch((err: Error) => {
      console.log(`Call protect failed <= ${err.message ?? err}`)
      return Promise.reject()
    }) ?? Promise.reject()
  }

  private resolveUid(protocol: number, source: string, target: string): number {
    return deviceInfo.sdkApiVersion >= 23 ?
      connection.getConnectOwnerUidSync(protocol, this.toNetAddress(source), this.toNetAddress(target)) : -1
  }

  private sendCallback(remote: rpc.RemoteObject, data: string): void {
    this.sender.send(remote, 0, data, null)
  }

  private sendResult(remote: rpc.RemoteObject, runTime: number): void {
    const options = new rpc.MessageOption()
    const send = rpc.MessageSequence.create()
    const reply = rpc.MessageSequence.create()
    options.setAsync(false)
    send.writeLong(runTime)
    remote.sendMessageRequest(0, send, reply, options).finally(() => {
      send.reclaim()
      reply.reclaim()
    })
  }

  handleSetEventListener(remote: rpc.RemoteObject): void {
    setEventListener((callbackData: string) => { this.sendCallback(remote, callbackData) })
  }

  handleInvokeMethod(data: string, remote: rpc.RemoteObject): void {
    invokeMethod((callbackData: string) => { this.sendCallback(remote, callbackData) }, data)
  }

  handleStartService(vpnOptions: VpnOptions, runTime: number, remote: rpc.RemoteObject): void {
    if (vpnOptions.enable) {
      const vpnConfig = this.toVpnConfig(vpnOptions)
      this.vpnConnection?.create(vpnConfig).then((fd: number) => startTUN(
        (socketFd: number): Promise<void> => this.protect(socketFd),
        (protocol: number, source: string, target: string): number => this.resolveUid(protocol, source, target),
        fd,
        vpnOptions.stack,
        this.toTunAddress(vpnOptions),
        this.toTunDns(vpnOptions),
      )).then(() => {
        if (deviceInfo.sdkApiVersion >= 20) {
          this.vpnConnection?.generateVpnId().then((vpnId) => { this.vpnId = vpnId })
        } else {
          this.vpnId = util.generateRandomUUID(true)
        }
        this.networkManager?.subscribe(updateDns)
        this.runTime = runTime !== 0 ? runTime : Date.now()
      }).catch((err: Error) => {
        console.log(`Call startTUN failed <= ${err.message ?? err}`)
      }).finally(() => {
        this.sendResult(remote, this.runTime)
      })
    } else {
      this.vpnId = undefined
      this.networkManager?.subscribe(updateDns)
      this.runTime = runTime !== 0 ? runTime : Date.now()
      this.sendResult(remote, this.runTime)
    }
  }

  handleStopService(remote: rpc.RemoteObject): void {
    (this.vpnId ? stopTun() : Promise.resolve()).then(() => {
      this.vpnId = undefined
      this.vpnConnection?.destroy()
      this.networkManager?.unsubscribe()
      this.runTime = 0
      this.sendResult(remote, this.runTime)
    })
  }

  handleGetRunTime(reply: rpc.MessageSequence): void {
    reply.writeLong(this.runTime)
  }

  handleQuickSetup(initParams: string, setupParams: string, remote: rpc.RemoteObject): void {
    quickSetup((callbackData: string) => { this.sendCallback(remote, callbackData) }, initParams, setupParams)
  }
}

