import Foundation

@objc public class AudioSession: NSObject {
    @objc public func echo(_ value: String) -> String {
        print(value)
        return value
    }
}
