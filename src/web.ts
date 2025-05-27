import { WebPlugin } from '@capacitor/core';

import type { AudioSessionPlugin } from './definitions';

export class AudioSessionWeb extends WebPlugin implements AudioSessionPlugin {

  async configureAudioSession(_options?: {
    allowMixing?: boolean;
    backgroundAudio?: boolean;
  }): Promise<{ configured: boolean; category: string; options: number[] }> {
    throw this.unimplemented('Not implemented on web.');
  }

  async addListeners(): Promise<{ listenersAdded: boolean }> {
    throw this.unimplemented('Not implemented on web.');
  }

  async removeAudioListeners(): Promise<{ listenersRemoved: boolean }> {
    throw this.unimplemented('Not implemented on web.');
  }

  async setActive(_options: { active: boolean }): Promise<{ active: boolean }> {
    throw this.unimplemented('Not implemented on web.');
  }

  async updateNowPlaying(_options: {
    title?: string;
    artist?: string;
    duration?: number;
    currentTime?: number;
    isPlaying?: boolean;
  }): Promise<{ updated: boolean }> {
    throw this.unimplemented('Not implemented on web.');
  }
}