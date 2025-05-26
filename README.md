# Capacitor Audio Session Plugin

A Capacitor plugin for iOS audio session management with comprehensive interruption handling.

## Features

- Configure audio session for background playback
- Handle audio interruptions (calls, system alerts, etc.)
- Detect route changes (headphones plugged/unplugged)
- Background audio support
- TypeScript support

## Installation

```bash
npm install capacitor-audio-session
npx cap sync
```

## iOS Setup

Add background audio capability to your `Info.plist`:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

## Usage

```typescript
import { AudioSession } from 'capacitor-audio-session';

// Configure the audio session
await AudioSession.configureAudioSession();

// Add listeners for interruptions
await AudioSession.addListeners();

// Listen for interruption events
AudioSession.addListener('audioInterruption', (event) => {
  if (event.type === 'began') {
    // Pause your audio
    console.log('Audio interrupted:', event.reason);
  } else if (event.type === 'ended' && event.options?.should_resume) {
    // Resume your audio
    console.log('Can resume audio');
  }
});

// Set audio session active/inactive
await AudioSession.setActive({ active: true });
```

## API

### configureAudioSession()

Configures the audio session for playback with background audio support.

```typescript
await AudioSession.configureAudioSession();
```

### addListeners()

Adds listeners for audio interruptions and route changes.

```typescript
await AudioSession.addListeners();
```

### removeAllListeners()

Removes all audio session listeners.

```typescript
await AudioSession.removeAllListeners();
```

### setActive(options)

Sets the audio session active or inactive.

```typescript
await AudioSession.setActive({ active: true });
```

### Event Listeners

#### audioInterruption

Fired when audio is interrupted or interruption ends.

```typescript
AudioSession.addListener('audioInterruption', (event) => {
  console.log('Interruption event:', event);
});
```

Event object:
- `type`: 'began' | 'ended'
- `reason`: 'call' | 'app_suspended' | 'builtin_app' | 'system' | 'route_change' | 'category_change'
- `options.should_resume`: boolean (only for 'ended' events)

## Platform Support

| Platform | Status |
|----------|--------|
| iOS      | ✅     |
| Android  | ❌     |
| Web      | ⚠️ (stub implementation) |

## License

MIT