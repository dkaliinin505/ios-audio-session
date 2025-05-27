export interface AudioSessionPlugin {
  configureAudioSession(options?: {
    allowMixing?: boolean;
    backgroundAudio?: boolean;
  }): Promise<{ configured: boolean; category: string; options: number[] }>;

  addListeners(): Promise<{ listenersAdded: boolean }>;

  removeAllListeners(): Promise<{ listenersRemoved: boolean }>;

  setActive(options: { active: boolean }): Promise<{ active: boolean }>;

  updateNowPlaying(options: {
    title?: string;
    artist?: string;
    duration?: number;
    currentTime?: number;
    isPlaying?: boolean;
  }): Promise<{ updated: boolean }>;

  addListener(
      eventName: 'audioInterruption',
      listenerFunc: (event: AudioInterruptionEvent) => void
  ): Promise<PluginListenerHandle>;

  addListener(
      eventName: 'audioRouteChange',
      listenerFunc: (event: AudioRouteChangeEvent) => void
  ): Promise<PluginListenerHandle>;

  addListener(
      eventName: 'appStateChange',
      listenerFunc: (event: AppStateChangeEvent) => void
  ): Promise<PluginListenerHandle>;
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

export interface PluginListenerHandle {
  remove(): Promise<void>;
}