import Foundation
import Capacitor
import AVFoundation

@objc(AudioSessionPlugin)
public class AudioSessionPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "AudioSessionPlugin"
    public let jsName = "AudioSession"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "configureAudioSession", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "addListeners", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "removeAllListeners", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setActive", returnType: CAPPluginReturnPromise)
    ]

    private var isConfigured = false

    override public func load() {
        super.load()
        print("AudioSessionPlugin: Plugin loaded")
    }

    @objc func configureAudioSession(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            do {
                let audioSession = AVAudioSession.sharedInstance()

                // Configure for playback with background audio
                try audioSession.setCategory(
                    .playback,
                    mode: .default,
                    options: [.allowBluetooth, .allowBluetoothA2DP, .allowAirPlay]
                )

                // Set active
                try audioSession.setActive(true, options: [])

                self.isConfigured = true
                print("AudioSessionPlugin: Audio session configured successfully")
                call.resolve()

            } catch {
                print("AudioSessionPlugin: Failed to configure audio session: \(error)")
                call.reject("Failed to configure audio session: \(error.localizedDescription)")
            }
        }
    }

    @objc func addListeners(_ call: CAPPluginCall) {
        if !isConfigured {
            call.reject("Audio session not configured. Call configureAudioSession first.")
            return
        }

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

        print("AudioSessionPlugin: Listeners added")
        call.resolve()
    }

    @objc func removeAllListeners(_ call: CAPPluginCall) {
        NotificationCenter.default.removeObserver(
            self,
            name: AVAudioSession.interruptionNotification,
            object: nil
        )

        NotificationCenter.default.removeObserver(
            self,
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )

        print("AudioSessionPlugin: All listeners removed")
        call.resolve()
    }

    @objc func setActive(_ call: CAPPluginCall) {
        let active = call.getBool("active") ?? true

        DispatchQueue.main.async {
            do {
                let audioSession = AVAudioSession.sharedInstance()
                let options: AVAudioSession.SetActiveOptions = active ? [] : [.notifyOthersOnDeactivation]

                try audioSession.setActive(active, options: options)

                print("AudioSessionPlugin: Audio session set to \(active ? "active" : "inactive")")
                call.resolve()

            } catch {
                print("AudioSessionPlugin: Failed to set audio session active: \(error)")
                call.reject("Failed to set audio session active: \(error.localizedDescription)")
            }
        }
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
            eventData["type"] = "began"

            // Determine interruption reason
            if let reasonValue = userInfo[AVAudioSessionInterruptionReasonKey] as? UInt,
               let reason = AVAudioSession.InterruptionReason(rawValue: reasonValue) {
                switch reason {
                case .default:
                    eventData["reason"] = "call"
                case .appWasSuspended:
                    eventData["reason"] = "app_suspended"
                case .builtInMicMuted:
                    eventData["reason"] = "builtin_app"
                @unknown default:
                    eventData["reason"] = "system"
                }
            } else {
                eventData["reason"] = "call"
            }

            print("AudioSessionPlugin: Interruption began - \(eventData["reason"] ?? "unknown")")

        case .ended:
            eventData["type"] = "ended"

            // Check if we should resume
            var shouldResume = false
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                shouldResume = options.contains(.shouldResume)
            }

            eventData["options"] = [
                "should_resume": shouldResume
            ]

            print("AudioSessionPlugin: Interruption ended - should resume: \(shouldResume)")

        @unknown default:
            print("AudioSessionPlugin: Unknown interruption type")
            return
        }

        // Notify JavaScript
        notifyListeners("audioInterruption", data: eventData)
    }

    @objc private func audioSessionRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        // Handle specific route changes that might affect playback
        switch reason {
        case .oldDeviceUnavailable:
            // Headphones unplugged, etc.
            let eventData: [String: Any] = [
                "type": "began",
                "reason": "route_change"
            ]
            print("AudioSessionPlugin: Route change - device unavailable")
            notifyListeners("audioInterruption", data: eventData)

        case .override, .categoryChange:
            let eventData: [String: Any] = [
                "type": "began",
                "reason": "category_change"
            ]
            print("AudioSessionPlugin: Route change - category/override")
            notifyListeners("audioInterruption", data: eventData)

        default:
            print("AudioSessionPlugin: Route change - \(reason.rawValue)")
            break
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}