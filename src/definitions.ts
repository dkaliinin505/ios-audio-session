import type { Plugin } from '@capacitor/core';

export interface AudioSessionPlugin extends Plugin {
  configureAudioSession(options?: {
    allowMixing?: boolean;
    backgroundAudio?: boolean;
    category?: 'playback' | 'playAndRecord' | 'record' | 'ambient' | 'soloAmbient';
  }): Promise<{ configured: boolean; category: string; options: number[] }>;

  addListeners(): Promise<{ listenersAdded: boolean }>;

  removeAudioListeners(): Promise<{ listenersRemoved: boolean }>;

  setActive(options: { active: boolean }): Promise<{ active: boolean }>;

  updateNowPlaying(options: {
    title?: string;
    artist?: string;
    duration?: number;
    currentTime?: number;
    isPlaying?: boolean;
  }): Promise<{ updated: boolean }>;
}

export interface AudioInterruptionEvent {
  type: 'began' | 'ended';
  timestamp: number;
  reason?: 'call' | 'app_suspended' | 'builtin_mic_muted' | 'system';
  shouldResume?: boolean;
}

export interface AudioRouteChangeEvent {
  type: 'route_change';
  reason: 'device_unavailable' | 'device_available' | 'category_change';
  action: 'pause' | 'continue';
  timestamp: number;
}

export interface AppStateChangeEvent {
  type: 'background' | 'foreground';
  timestamp: number;
}