import { WebPlugin } from '@capacitor/core';

import type { PluginListenerHandle } from '@capacitor/core';
import type { AudioSessionPlugin, AudioInterruptionEvent, AudioRouteChangeEvent, AppStateChangeEvent } from './definitions';

export class AudioSessionWeb extends WebPlugin implements AudioSessionPlugin {

  async configureAudioSession(_options?: {
    allowMixing?: boolean;
    backgroundAudio?: boolean;
    autoSetupListeners?: boolean;
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

  // Event listener overloads
  async addListener(
      eventName: 'audioInterruption',
      listenerFunc: (event: AudioInterruptionEvent) => void
  ): Promise<PluginListenerHandle>;
  async addListener(
      eventName: 'audioRouteChange',
      listenerFunc: (event: AudioRouteChangeEvent) => void
  ): Promise<PluginListenerHandle>;
  async addListener(
      eventName: 'appStateChange',
      listenerFunc: (event: AppStateChangeEvent) => void
  ): Promise<PluginListenerHandle>;
  async addListener(
      eventName: 'audioSessionReactivated',
      listenerFunc: (event: { timestamp: number; ready: boolean }) => void
  ): Promise<PluginListenerHandle>;
  async addListener(
      eventName: string,
      listenerFunc: (event: any) => void
  ): Promise<PluginListenerHandle> {
    // Use the parent WebPlugin's addListener method
    return super.addListener(eventName, listenerFunc);
  }
}