@MainActor
protocol LaunchAtLoginManaging: AnyObject {
    var isEnabled: Bool { get }

    func setEnabled(_ isEnabled: Bool) throws
}
