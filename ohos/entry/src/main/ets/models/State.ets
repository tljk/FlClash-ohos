export enum AccessControlMode {
  ACCEPT_SELECTED = "acceptSelected",
  REJECT_SELECTED = "rejectSelected",
}

export class AccessControlProps {
  enable: boolean = false
  mode: AccessControlMode = AccessControlMode.ACCEPT_SELECTED
  acceptList: string[] = []
  rejectList: string[] = []

  constructor() {
  }
}

export class VpnOptions {
  enable: boolean = false
  port: number = 0
  ipv6: boolean = false
  dnsHijacking: boolean = false
  accessControlProps: AccessControlProps = new AccessControlProps()
  allowBypass: boolean = false
  systemProxy: boolean = false
  bypassDomain: string[] = []
  stack: string = ""
  routeAddress: string[] = []

  constructor() {
  }
}

export class SetupParams {
  'test-url': string = ""
  'selected-map': Record<string, string> = {}

  constructor() {
  }
}

export class State {
  startTip: string = "Starting VPN..."
  stopTip: string = "Stopping VPN..."
  crashlytics: boolean = true
  currentProfileName: string = "FlClash"
  stopText: string = "Stop"
  onlyStatisticsProxy: boolean = false
  vpnOptions: VpnOptions | null = null
  setupParams: SetupParams | null = null

  constructor() {
  }
}