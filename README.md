# ios-audio-session

Small plugin to handle music interruption

## Install

```bash
npm install ios-audio-session
npx cap sync
```

## API

<docgen-index>

* [`configureAudioSession()`](#configureaudiosession)
* [`addListeners()`](#addlisteners)
* [`removeAllListeners()`](#removealllisteners)
* [`setActive(...)`](#setactive)
* [`addListener('audioInterruption', ...)`](#addlisteneraudiointerruption-)
* [Interfaces](#interfaces)

</docgen-index>

<docgen-api>
<!--Update the source file JSDoc comments and rerun docgen to update the docs below-->

### configureAudioSession()

```typescript
configureAudioSession() => Promise<void>
```

--------------------


### addListeners()

```typescript
addListeners() => Promise<void>
```

--------------------


### removeAllListeners()

```typescript
removeAllListeners() => Promise<void>
```

--------------------


### setActive(...)

```typescript
setActive(options: { active: boolean; }) => Promise<void>
```

| Param         | Type                              |
| ------------- | --------------------------------- |
| **`options`** | <code>{ active: boolean; }</code> |

--------------------


### addListener('audioInterruption', ...)

```typescript
addListener(eventName: 'audioInterruption', listenerFunc: (event: AudioInterruptionEvent) => void) => Promise<PluginListenerHandle>
```

| Param              | Type                                                                                          |
| ------------------ | --------------------------------------------------------------------------------------------- |
| **`eventName`**    | <code>'audioInterruption'</code>                                                              |
| **`listenerFunc`** | <code>(event: <a href="#audiointerruptionevent">AudioInterruptionEvent</a>) =&gt; void</code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

--------------------


### Interfaces


#### PluginListenerHandle

| Prop         | Type                                      |
| ------------ | ----------------------------------------- |
| **`remove`** | <code>() =&gt; Promise&lt;void&gt;</code> |


#### AudioInterruptionEvent

| Prop          | Type                                                                                                       |
| ------------- | ---------------------------------------------------------------------------------------------------------- |
| **`type`**    | <code>'began' \| 'ended'</code>                                                                            |
| **`reason`**  | <code>'call' \| 'app_suspended' \| 'builtin_app' \| 'system' \| 'route_change' \| 'category_change'</code> |
| **`options`** | <code>{ should_resume: boolean; }</code>                                                                   |

</docgen-api>
