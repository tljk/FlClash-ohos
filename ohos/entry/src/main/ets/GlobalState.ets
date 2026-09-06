import { State } from './models/State'

export enum RunState {
  start, pending, stop
}

export class GlobalState {
  get state(): State {
    if (!AppStorage.has('shared_state')) AppStorage.setOrCreate('shared_state', new State())
    return AppStorage.get('shared_state') as State
  }
  set state(state: State) {
    AppStorage.setOrCreate('shared_state', state)
  }
  get runTime(): number {
    if (!AppStorage.has('run_time')) AppStorage.setOrCreate('run_time', 0)
    return AppStorage.get('run_time') as number
  }
  set runTime(timestamp: number) {
    AppStorage.setOrCreate('run_time', timestamp)
  }
  get runState(): RunState {
    if (!AppStorage.has('run_state')) AppStorage.setOrCreate('run_state', RunState.stop)
    return AppStorage.get('run_state') as RunState
  }
  set runState(state: RunState) {
    AppStorage.setOrCreate('run_state', state)
  }
  get excludeFromRecent(): boolean {
    if (!AppStorage.has('exclude_recent')) AppStorage.setOrCreate('exclude_recent', false)
    return AppStorage.get<boolean>('exclude_recent') as boolean
  }
  set excludeFromRecent(state: boolean) {
    AppStorage.setOrCreate('exclude_recent', state)
  }
  get excludeState(): boolean {
    if (!AppStorage.has('exclude_state')) AppStorage.setOrCreate('exclude_state', false)
    return AppStorage.get<boolean>('exclude_state') as boolean
  }
  set excludeState(state: boolean) {
    AppStorage.setOrCreate('exclude_state', state)
  }
}

export const globalState = new GlobalState()