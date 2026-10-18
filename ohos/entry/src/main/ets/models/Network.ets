import { connection } from "@kit.NetworkKit";

export class Network {
  bearerTypes: connection.NetBearType[] = []
  dnses: connection.NetAddress[] = []

  constructor() {
  }
}
