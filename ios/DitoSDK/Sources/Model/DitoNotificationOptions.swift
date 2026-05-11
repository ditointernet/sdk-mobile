public struct DitoNotificationOptions {
    public var soundName: String?
    public var badgeEnabled: Bool

    public init(soundName: String? = nil, badgeEnabled: Bool = true) {
        self.soundName = soundName
        self.badgeEnabled = badgeEnabled
    }
}
