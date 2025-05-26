export interface AudioSessionPlugin {
  configureAudioSession(): Promise<void>;
  addListeners(): Promise<void>;
  removeAllListeners(): Promise<void>;
  setActive(options: { active: boolean }): Promise<void>;

  addListener(
      eventName: 'audioInterruption',
      listenerFunc: (event: AudioInterruptionEvent) => void,
  ): Promise<PluginListenerHandle>;
}

export interface AudioInterruptionEvent {
  type: 'began' | 'ended';
  reason?: 'call' | 'app_suspended' | 'builtin_app' | 'system' | 'route_change' | 'category_change';
  options?: {
    should_resume: boolean;
  };
}

export interface PluginListenerHandle {
  remove(): Promise<void>;
}