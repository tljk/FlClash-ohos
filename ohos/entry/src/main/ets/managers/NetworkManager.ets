import { connection } from "@kit.NetworkKit";
import { Network } from "../models/Network"

export default class NetworkManager {
  private netConnection: connection.NetConnection
  private networkMap: Map<number, Network> = new Map<number, Network>()
  private preDnsList: string[] = []

  constructor() {
    this.netConnection = connection.createNetConnection()
  }

  private asSocketAddressText(address: connection.NetAddress, port: number): string {
    if (address.family === 2) {
      return `[${address.address}]:${port}`
    }
    return `${address.address}:${port}`
  }

  private handleNetworkUpdate(callback: (s: string) => void): void {
    const best = Array.from(this.networkMap.values()).reduce((previousValue: Network, currentValue: Network) => {
      return Math.max(-1, ...currentValue.bearerTypes) > Math.max(-1, ...previousValue.bearerTypes) ? currentValue : previousValue
    }, new Network())
    const dnsList = best.dnses.map((address: connection.NetAddress) => this.asSocketAddressText(address, 53))
    if (dnsList.length === this.preDnsList.length && dnsList.every((dns: string, i: number) => dns === this.preDnsList[i])) return
    this.preDnsList = dnsList
    callback(Array.from(new Set(dnsList)).join(","))
  }

  subscribe(callback: (s: string) => void): Promise<void> {
    return new Promise((resolve, reject) => {
      this.netConnection.on("netAvailable", (netHandle: connection.NetHandle) => {
        if (netHandle?.netId) {
          this.networkMap.set(netHandle.netId, new Network())
          this.handleNetworkUpdate(callback)
        }
      })

      this.netConnection.on("netCapabilitiesChange", (netCapabilityInfo: connection.NetCapabilityInfo) => {
        const netId = netCapabilityInfo?.netHandle?.netId
        const bearerTypes = netCapabilityInfo?.netCap?.bearerTypes
        if (netId && bearerTypes) {
          const network = this.networkMap.get(netId)
          if (network) network.bearerTypes = bearerTypes
          this.handleNetworkUpdate(callback)
        }
      })

      this.netConnection.on("netConnectionPropertiesChange", (netConnectionPropertyInfo: connection.NetConnectionPropertyInfo) => {
        const netId = netConnectionPropertyInfo?.netHandle?.netId
        const dnses = netConnectionPropertyInfo?.connectionProperties?.dnses
        if (netId && dnses) {
          const network = this.networkMap.get(netId)
          if (network) network.dnses = dnses
          this.handleNetworkUpdate(callback)
        }
      })

      this.netConnection.on("netLost", (netHandle: connection.NetHandle) => {
        if (netHandle?.netId) {
          this.networkMap.delete(netHandle.netId)
          this.handleNetworkUpdate(callback)
        }
      })

      this.netConnection.register((err: Error) => {
        if(err) {
          reject(err)
        } else {
          resolve()
        }
      })
    })
  }

  unsubscribe(): Promise<void> {
    return new Promise((resolve, reject) => {
      this.netConnection.unregister((err: Error) => {
        if (err) {
          reject(err)
        }else {
          resolve()
        }
      })
    })
  }
}