/// Facts about the app that are not secrets but must be filled in before the store submission.
enum AppInfo {
    /// Contact shown in the User-Agent sent to the Are.na API. Empty until Neo fills it in
    /// (see docs/review-notes.md: an empty address blocks the submission).
    static let contactEmail = ""
}
