import { WebPlugin } from '@capacitor/core';

import type { AudioSessionPlugin } from './definitions';

export class AudioSessionWeb extends WebPlugin implements AudioSessionPlugin {
  async configureAudioSession(): Promise<void> {
    return
  }

  async startMonitoring(): Promise<void> {
    return
  }

  async stopMonitoring(): Promise<void> {
    return
  }

  async setActive(): Promise<void> {
    return
  }

  addListeners(): Promise<void> {
    return Promise.resolve(undefined);
  }
}