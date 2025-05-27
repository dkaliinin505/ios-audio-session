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

    override public func load() {
        super.load()
        print("AudioSessionPlugin: Plugin loaded")

        // Don't configure audio session immediately on load
        // Wait for explicit configuration call from JavaScript
    }

    private func configureInitialAudioSession() {
        // This method is now unused - keeping for reference
        // Audio session will be configured when configureAudioSession() is called
    }

    @objc func configureAudioSession(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            // --- DEBUG LOGS: start ---
            let allowMixing = call.getBool("allowMixing") ?? false
            let backgroundAudio = call.getBool("backgroundAudio") ?? true
            print("🔊 AudioSessionPlugin.configureAudioSession() called")
            print("    • allowMixing: \(allowMixing)")
            print("    • backgroundAudio: \(backgroundAudio)")
            // --- end debug ---

            do {
                let audioSession = AVAudioSession.sharedInstance()

                // assemble options
                var options: AVAudioSession.CategoryOptions = [
                    .allowBluetooth,
                    .allowBluetoothA2DP
                ]
                if allowMixing { options.insert(.mixWithOthers) }
                if backgroundAudio { options.insert(.duckOthers) }

                // --- DEBUG LOGS: before setCategory ---
                print("    → About to setCategory(.playback, mode:.default, options: \(options))")
                print("       current session.category: \(audioSession.category.rawValue)")
                print("       current session.categoryOptions rawValue: \(audioSession.categoryOptions.rawValue)")
                // --- end debug ---

                try audioSession.setCategory(.playback, mode: .default, options: options)

                // --- DEBUG LOGS: after setCategory success ---
                print("    ✅ setCategory succeeded!")
                print("       new session.category: \(audioSession.category.rawValue)")
                print("       new session.categoryOptions rawValue: \(audioSession.categoryOptions.rawValue)")
                // --- end debug ---

                self.isConfigured = true
                call.resolve([
                    "configured": true,
                    "category": audioSession.category.rawValue,
                    "optionsRaw": audioSession.categoryOptions.rawValue
                ])
            }
            catch let error as NSError {
                // --- DEBUG LOGS: on error ---
                print("    ❌ setCategory failed with NSError: domain=\(error.domain), code=\(error.code)")
                print("       attempted options rawValue: \(String(describing: (error.userInfo[AVAudioSessionCategoryOptionsKey] as? UInt)))")
                // --- end debug ---

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

        print("AudioSessionPlugin: All listeners added")
        call.resolve(["listenersAdded": true])
    }

    @objc func removeAudioListeners(_ call: CAPPluginCall) {
        NotificationCenter.default.removeObserver(self)
        print("AudioSessionPlugin: All listeners removed")
        call.resolve(["listenersRemoved": true])
    }

    @objc func setActive(_ call: CAPPluginCall) {
        let active = call.getBool("active") ?? true

        DispatchQueue.main.async {
            do {
                let audioSession = AVAudioSession.sharedInstance()

                if active {
                    // When activating, first ensure we have a category set
                    if !self.isConfigured {
                        // Set a basic category if none has been configured
                        try audioSession.setCategory(.playback, mode: .default, options: [.allowBluetooth, .allowBluetoothA2DP])
                        self.isConfigured = true
                        print("AudioSessionPlugin: Set default category before activation")
                    }

                    // Activate the session
                    try audioSession.setActive(true, options: [])
                } else {
                    // When deactivating, notify other apps they can resume
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
                case 560030580: // kAudioSessionIncompatibleCategory
                    errorMessage = "Incompatible audio session category"
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

    @objc private func audioSessionInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            print("AudioSessionPlugin: Invalid interruption notification")
            return
        }

        var eventData: [String: Any] = [:]

        switch type {
        case .began:
            wasInterrupted = true
            eventData["type"] = "began"
            eventData["timestamp"] = Date().timeIntervalSince1970

            // Determine interruption reason
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
            eventData["timestamp"] = Date().timeIntervalSince1970

            var shouldResume = false
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                shouldResume = options.contains(.shouldResume)
            }

            eventData["shouldResume"] = shouldResume

            // Try to reactivate audio session after interruption
            if shouldResume {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    do {
                        try AVAudioSession.sharedInstance().setActive(true, options: [])
                        print("AudioSessionPlugin: Audio session reactivated after interruption")
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

        // Notify JavaScript with more detail
        notifyListeners("audioInterruption", data: eventData)
    }

    @objc private func audioSessionRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        var eventData: [String: Any] = [
            "timestamp": Date().timeIntervalSince1970
        ]

        switch reason {
        case .oldDeviceUnavailable:
            // Headphones unplugged, etc.
            eventData["type"] = "route_change"
            eventData["reason"] = "device_unavailable"
            eventData["action"] = "pause" // Suggest pausing
            print("AudioSessionPlugin: Route change - device unavailable")

        case .newDeviceAvailable:
            eventData["type"] = "route_change"
            eventData["reason"] = "device_available"
            eventData["action"] = "continue" // Can continue playing
            print("AudioSessionPlugin: Route change - new device available")

        case .override, .categoryChange:
            eventData["type"] = "route_change"
            eventData["reason"] = "category_change"
            eventData["action"] = "pause"
            print("AudioSessionPlugin: Route change - category/override")

        default:
            print("AudioSessionPlugin: Route change - \(reason.rawValue)")
            return
        }

        notifyListeners("audioRouteChange", data: eventData)
    }

    @objc private func appDidEnterBackground(notification: Notification) {
        let eventData: [String: Any] = [
            "type": "background",
            "timestamp": Date().timeIntervalSince1970
        ]
        notifyListeners("appStateChange", data: eventData)
    }

    @objc private func appWillEnterForeground(notification: Notification) {
        let eventData: [String: Any] = [
            "type": "foreground",
            "timestamp": Date().timeIntervalSince1970
        ]
        notifyListeners("appStateChange", data: eventData)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}