import Foundation
import Capacitor
import AVFoundation
import MediaPlayer

@objc(AudioSessionPlugin)
public class AudioSessionPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "AudioSessionPlugin"
    public let jsName = "AudioSession"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "configureAudioSession", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "addListeners", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "removeAudioListeners", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setActive", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "updateNowPlaying", returnType: CAPPluginReturnPromise)
    ]

    private var isConfigured = false
    private var wasInterrupted = false
    private var wasPlayingBeforeInterruption = false
    private var listenersAdded = false

    // Event deduplication
    private var lastRouteChangeEvent: [String: Any]?
    private var lastInterruptionEvent: [String: Any]?
    private let eventDeduplicationInterval: TimeInterval = 1.0 // 1 second

    override public func load() {
        super.load()
        print("AudioSessionPlugin: Plugin loaded")
    }

    @objc func configureAudioSession(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            let allowMixing = call.getBool("allowMixing") ?? false
            let backgroundAudio = call.getBool("backgroundAudio") ?? true

            do {
                let audioSession = AVAudioSession.sharedInstance()

                var options: AVAudioSession.CategoryOptions = [
                    .allowBluetooth,
                    .allowBluetoothA2DP,
                    .allowAirPlay
                ]

                if allowMixing {
                    options.insert(.mixWithOthers)
                }

                if backgroundAudio {
                    options.insert(.duckOthers)
                }

                // Use the dynamic options instead of static values
                try audioSession.setCategory(
                    .playback,
                    mode: .default,
                    options: [.mixWithOthers, .duckOthers]
                )

                try audioSession.setActive(true, options: [.mixWithOthers, .duckOthers])

                self.isConfigured = true

                call.resolve([
                    "configured": true,
                    "category": audioSession.category.rawValue,
                    "optionsRaw": audioSession.categoryOptions.rawValue
                ])

                print("AudioSessionPlugin: Audio session configured and activated")
            }
            catch let error as NSError {
                print("AudioSessionPlugin: Configuration error: \(error)")

                var errorMessage = "Failed to configure audio session"
                switch error.code {
                case -50:
                    errorMessage = "Invalid audio session property or state"
                case -560557673:
                    errorMessage = "Audio session not initialized"
                case -560030580:
                    errorMessage = "Audio session already initialized"
                default:
                    errorMessage = "Audio session error: \(error.localizedDescription)"
                }
                call.reject(errorMessage)
            }
        }
    }

    @objc func addListeners(_ call: CAPPluginCall) {
        // Prevent multiple listener registration
        if listenersAdded {
            print("AudioSessionPlugin: Listeners already added, skipping")
            call.resolve(["listenersAdded": true])
            return
        }

        // Remove existing observers first
        NotificationCenter.default.removeObserver(self)

        // Add interruption observer
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(audioSessionInterruption),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )

        // Add route change observer
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(audioSessionRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance()
        )

        // Add app lifecycle observers
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )

        listenersAdded = true
        print("AudioSessionPlugin: All listeners added")
        call.resolve(["listenersAdded": true])
    }

    @objc func removeAudioListeners(_ call: CAPPluginCall) {
        NotificationCenter.default.removeObserver(self)
        listenersAdded = false
        lastRouteChangeEvent = nil
        lastInterruptionEvent = nil
        print("AudioSessionPlugin: All listeners removed")
        call.resolve(["listenersRemoved": true])
    }

    @objc func setActive(_ call: CAPPluginCall) {
        let active = call.getBool("active") ?? true

        DispatchQueue.main.async {
            do {
                let audioSession = AVAudioSession.sharedInstance()

                if active {
                    if !self.isConfigured {
                        try audioSession.setCategory(.playback, mode: .default, options: [
                            .allowBluetooth,
                            .allowBluetoothA2DP,
                            .mixWithOthers,
                            .duckOthers
                        ])
                        self.isConfigured = true
                        print("AudioSessionPlugin: Set default category before activation")
                    }

                    try audioSession.setActive(true, options: [])
                } else {
                    try audioSession.setActive(false, options: [.notifyOthersOnDeactivation])
                }

                print("AudioSessionPlugin: Audio session set to \(active ? "active" : "inactive")")
                call.resolve(["active": active])

            } catch let error as NSError {
                print("AudioSessionPlugin: Failed to set audio session active: \(error) - Code: \(error.code)")

                var errorMessage = "Failed to set audio session active"
                switch error.code {
                case -50:
                    errorMessage = "Invalid audio session state for activation"
                case 560030580:
                    errorMessage = "Incompatible audio session category"
                case -560030580: // Negative version of the same error
                    errorMessage = "Audio session already active/inactive"
                default:
                    errorMessage = "Audio session activation error: \(error.localizedDescription)"
                }

                call.reject(errorMessage)
            }
        }
    }

    @objc func updateNowPlaying(_ call: CAPPluginCall) {
        let title = call.getString("title") ?? ""
        let artist = call.getString("artist") ?? ""
        let duration = call.getDouble("duration") ?? 0.0
        let currentTime = call.getDouble("currentTime") ?? 0.0
        let isPlaying = call.getBool("isPlaying") ?? false

        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = title
        nowPlayingInfo[MPMediaItemPropertyArtist] = artist
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo

        call.resolve(["updated": true])
    }

    // MARK: - Event Deduplication Helper
    private func isDuplicateEvent(_ eventData: [String: Any], lastEvent: [String: Any]?, eventType: String) -> Bool {
        guard let lastEvent = lastEvent,
              let currentTimestamp = eventData["timestamp"] as? TimeInterval,
              let lastTimestamp = lastEvent["timestamp"] as? TimeInterval else {
            return false
        }

        // Check if events are too close in time
        let timeDifference = abs(currentTimestamp - lastTimestamp)
        if timeDifference > eventDeduplicationInterval {
            return false
        }

        // Compare event content (excluding timestamp)
        var currentEventWithoutTimestamp = eventData
        var lastEventWithoutTimestamp = lastEvent
        currentEventWithoutTimestamp.removeValue(forKey: "timestamp")
        lastEventWithoutTimestamp.removeValue(forKey: "timestamp")

        return NSDictionary(dictionary: currentEventWithoutTimestamp).isEqual(to: lastEventWithoutTimestamp)
    }

    @objc private func audioSessionInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            print("AudioSessionPlugin: Invalid interruption notification")
            return
        }

        var eventData: [String: Any] = [
            "timestamp": Date().timeIntervalSince1970
        ]

        print("AudioSessionPlugin: Interruption notification received - type: \(type.rawValue)")

        switch type {
        case .began:
            wasInterrupted = true
            eventData["type"] = "began"

            if let reasonValue = userInfo[AVAudioSessionInterruptionReasonKey] as? UInt,
               let reason = AVAudioSession.InterruptionReason(rawValue: reasonValue) {
                switch reason {
                case .default:
                    eventData["reason"] = "call"
                case .appWasSuspended:
                    eventData["reason"] = "app_suspended"
                case .builtInMicMuted:
                    eventData["reason"] = "builtin_mic_muted"
                @unknown default:
                    eventData["reason"] = "system"
                }
            } else {
                eventData["reason"] = "call"
            }

            print("AudioSessionPlugin: Interruption began - \(eventData["reason"] ?? "unknown")")

        case .ended:
            eventData["type"] = "ended"

            var shouldResume = false
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                shouldResume = options.contains(.shouldResume)
            }

            eventData["shouldResume"] = shouldResume

            if shouldResume {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    do {
                        try AVAudioSession.sharedInstance().setActive(true, options: [])
                        print("AudioSessionPlugin: Audio session reactivated after interruption")

                        // Notify JS that session is ready for playback
                        self.notifyListeners("audioSessionReady", data: [
                            "timestamp": Date().timeIntervalSince1970,
                            "reason": "interruption_ended"
                        ])
                    } catch {
                        print("AudioSessionPlugin: Failed to reactivate audio session: \(error)")
                    }
                }
            }

            print("AudioSessionPlugin: Interruption ended - should resume: \(shouldResume)")
            wasInterrupted = false

        @unknown default:
            print("AudioSessionPlugin: Unknown interruption type")
            return
        }

        // Check for duplicate events
        if !isDuplicateEvent(eventData, lastEvent: lastInterruptionEvent, eventType: "interruption") {
            lastInterruptionEvent = eventData
            notifyListeners("audioInterruption", data: eventData)
        } else {
            print("AudioSessionPlugin: Duplicate interruption event filtered out")
        }
    }

    @objc private func audioSessionRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        print("AudioSessionPlugin: Route change notification received - reason: \(reason.rawValue)")

        var eventData: [String: Any] = [
            "timestamp": Date().timeIntervalSince1970,
            "type": "route_change"
        ]

        switch reason {
        case .oldDeviceUnavailable:
            eventData["reason"] = "device_unavailable"
            eventData["action"] = "pause"
            print("AudioSessionPlugin: Route change - device unavailable")

        case .newDeviceAvailable:
            eventData["reason"] = "device_available"
            eventData["action"] = "continue"
            print("AudioSessionPlugin: Route change - new device available")

        case .override, .categoryChange:
            eventData["reason"] = "category_change"
            eventData["action"] = "pause"
            print("AudioSessionPlugin: Route change - category/override")

        case .wakeFromSleep:
            eventData["reason"] = "wake_from_sleep"
            eventData["action"] = "continue"
            print("AudioSessionPlugin: Route change - wake from sleep")

        case .noSuitableRouteForCategory:
            eventData["reason"] = "no_suitable_route"
            eventData["action"] = "pause"
            print("AudioSessionPlugin: Route change - no suitable route")

        default:
            print("AudioSessionPlugin: Route change - other reason: \(reason.rawValue)")
            eventData["reason"] = "other"
            eventData["action"] = "continue"
        }

        if !isDuplicateEvent(eventData, lastEvent: lastRouteChangeEvent, eventType: "route_change") {
            lastRouteChangeEvent = eventData
            notifyListeners("audioRouteChange", data: eventData)
        } else {
            print("AudioSessionPlugin: Duplicate route change event filtered out")
        }
    }

    @objc private func appDidEnterBackground(notification: Notification) {
        let eventData: [String: Any] = [
            "type": "background",
            "timestamp": Date().timeIntervalSince1970
        ]

        // Try to keep audio session active in background
        DispatchQueue.main.async {
            do {
                try AVAudioSession.sharedInstance().setActive(true, options: [])
                print("AudioSessionPlugin: Maintained audio session in background")
            } catch {
                print("AudioSessionPlugin: Failed to maintain audio session in background: \(error)")
            }
        }

        notifyListeners("appStateChange", data: eventData)
    }

    @objc private func appWillEnterForeground(notification: Notification) {
        let eventData: [String: Any] = [
            "type": "foreground",
            "timestamp": Date().timeIntervalSince1970
        ]

        // Ensure audio session is active when returning to foreground
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            do {
                try AVAudioSession.sharedInstance().setActive(true, options: [])
                print("AudioSessionPlugin: Reactivated audio session in foreground")
            } catch {
                print("AudioSessionPlugin: Failed to reactivate audio session in foreground: \(error)")
            }
        }

        notifyListeners("appStateChange", data: eventData)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}