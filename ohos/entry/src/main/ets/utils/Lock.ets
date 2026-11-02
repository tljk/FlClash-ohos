export class Lock {
  private locked: boolean = false
  private waiters: Map<string, () => void> = new Map()

  acquire(name: string): Promise<() => void> {
    return new Promise<() => void>((resolve: (release: () => void) => void) => {
      const release = (): void => {
        const next = this.waiters.keys().next()
        if (next.done) {
          this.locked = false
          return
        }
        const nextName = next.value
        const grant = this.waiters.get(nextName)
        this.waiters.delete(nextName)
        if (grant !== undefined) grant()
      }
      if (this.locked) {
        this.waiters.set(name, () => resolve(release))
      } else {
        this.locked = true
        resolve(release)
      }
    })
  }

  revoke(name: string): void {
    this.waiters.delete(name)
  }

  isLocked(): boolean {
    return this.locked
  }
}
