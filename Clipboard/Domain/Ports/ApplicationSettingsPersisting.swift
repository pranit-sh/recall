@MainActor
protocol ApplicationSettingsPersisting: AnyObject {
    func loadHistoryLimit() throws -> Int?
    func saveHistoryLimit(_ limit: Int) throws
    func loadDisplayLimit() throws -> Int?
    func saveDisplayLimit(_ limit: Int) throws
    func loadImageLimit() throws -> Int?
    func saveImageLimit(_ limit: Int) throws
    func loadImageStorageLimitInMegabytes() throws -> Int?
    func saveImageStorageLimitInMegabytes(_ limit: Int) throws
}
