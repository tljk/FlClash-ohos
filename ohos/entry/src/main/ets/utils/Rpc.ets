import { rpc } from '@kit.IPCKit'
import { util } from '@kit.ArkTS'

const CHUNK_SIZE = 4096

export class ChunkedSender {
  private nextSessionId: number = 0

  async send(remote: rpc.RemoteObject, code: number, value: string, writeExtra: ((send: rpc.MessageSequence) => void) | null): Promise<rpc.RequestResult> {
    const sessionId = this.nextSessionId
    this.nextSessionId = this.nextSessionId + 1
    const bytes = util.TextEncoder.create().encodeInto(value)
    const chunkCount = bytes.length === 0 ? 1 : Math.ceil(bytes.length / CHUNK_SIZE)
    let result: rpc.RequestResult | null = null
    for (let i = 0; i < chunkCount; i++) {
      const start = i * CHUNK_SIZE
      const end = Math.min(start + CHUNK_SIZE, bytes.length)
      const chunk = bytes.subarray(start, end)
      const isLast = i === chunkCount - 1
      const options = new rpc.MessageOption()
      options.setAsync(false)
      const send = rpc.MessageSequence.create()
      const reply = rpc.MessageSequence.create()
      send.writeInt(sessionId)
      send.writeBoolean(isLast)
      send.writeInt(chunk.length)
      if (chunk.length > 0) send.writeByteArray(Array.from(chunk))
      if (isLast && writeExtra !== null) writeExtra(send)
      result = await remote.sendMessageRequest(code, send, reply, options).finally(() => {
        send.reclaim()
        reply.reclaim()
      })
    }
    return result as rpc.RequestResult
  }
}

export class ChunkedReader {
  private buffers: Map<number, number[][]> = new Map<number, number[][]>()

  read(sequence: rpc.MessageSequence): string | null {
    const sessionId = sequence.readInt()
    const isLast = sequence.readBoolean()
    const length = sequence.readInt()
    const chunk = length > 0 ? sequence.readByteArray() : []
    const existing = this.buffers.get(sessionId)
    const parts = existing === undefined ? [] : existing
    parts.push(chunk)
    if (!isLast) {
      this.buffers.set(sessionId, parts)
      return null
    }
    this.buffers.delete(sessionId)
    let totalLength = 0
    for (let i = 0; i < parts.length; i++) {
      totalLength = totalLength + parts[i].length
    }
    const allBytes = new Uint8Array(totalLength)
    let offset = 0
    for (let i = 0; i < parts.length; i++) {
      allBytes.set(parts[i], offset)
      offset = offset + parts[i].length
    }
    return util.TextDecoder.create().decodeToString(allBytes)
  }
}
