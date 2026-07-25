import { rpc } from '@kit.IPCKit'
import { util } from '@kit.ArkTS'

export function writeLargeString(sequence: rpc.MessageSequence, value: string): void {
  const bytes = util.TextEncoder.create().encodeInto(value)
  sequence.writeInt(bytes.byteLength)
  sequence.writeRawDataBuffer(bytes.buffer, bytes.byteLength)
}

export function readLargeString(sequence: rpc.MessageSequence): string {
  const length = sequence.readInt()
  const buffer = sequence.readRawDataBuffer(length)
  return util.TextDecoder.create().decodeToString(new Uint8Array(buffer))
}
