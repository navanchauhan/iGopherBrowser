public enum TelemetryDeck {
    public final class Config {
        public let appID: String
        public var analyticsDisabled: Bool

        public init(appID: String, analyticsDisabled: Bool = false) {
            self.appID = appID
            self.analyticsDisabled = analyticsDisabled
        }
    }

    public static func initialize(config: Config) {}

    public static func terminate() {}

    public static func signal(_ name: String) {}

    public static func signal(_ name: String, parameters: [String: String]) {}
}
