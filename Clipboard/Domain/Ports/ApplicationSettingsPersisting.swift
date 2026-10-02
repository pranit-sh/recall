@MainActor
protocol ApplicationSettingsPersisting: AnyObject {
    func loadHistoryLimit() throws -> Int?
    func saveHistoryLimit(_ limit: Int) throws
    func loadDisplayLimit() throws -> Int?
    func saveDisplayLimit(_ limit: Int) throws
}
