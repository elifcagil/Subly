import Foundation

/// Official websites for well-known services, so a deleted subscription can
/// hand the user straight to the place where the real cancellation happens.
///
/// Matching is by name keyword (case-insensitive, diacritics ignored), so a
/// subscription the user typed as "netflix family" still resolves.
enum ServiceWebsiteDirectory {

    private static let entries: [(keywords: [String], url: String)] = [
        (["netflix"], "https://www.netflix.com/youraccount"),
        (["spotify"], "https://www.spotify.com/account/subscription/"),
        (["apple music", "apple one", "icloud", "apple tv", "apple arcade", "apple"], "https://support.apple.com/HT202039"),
        (["youtube"], "https://www.youtube.com/paid_memberships"),
        (["disney"], "https://www.disneyplus.com/account"),
        (["amazon", "prime video"], "https://www.amazon.com/mc"),
        (["chatgpt", "openai"], "https://chatgpt.com/#settings/Subscription"),
        (["claude", "anthropic"], "https://claude.ai/settings/billing"),
        (["linkedin"], "https://www.linkedin.com/premium/manage"),
        (["notion"], "https://www.notion.so/my-account"),
        (["github", "copilot"], "https://github.com/settings/billing"),
        (["dropbox"], "https://www.dropbox.com/account/plan"),
        (["google one", "google"], "https://one.google.com/settings"),
        (["strava"], "https://www.strava.com/settings/subscription"),
        (["peloton"], "https://members.onepeloton.com/preferences/subscriptions"),
        (["calm"], "https://www.calm.com/manage-subscription"),
        (["new york times", "nyt", "nytimes"], "https://myaccount.nytimes.com/seg/subscription"),
        (["medium"], "https://medium.com/me/settings/membership"),
        (["hbo", "max"], "https://www.max.com/account"),
        (["hulu"], "https://secure.hulu.com/account"),
        (["exxen"], "https://www.exxen.com/account"),
        (["blutv", "blu tv"], "https://www.blutv.com/hesabim"),
        (["gain"], "https://gain.tv"),
        (["tabii"], "https://www.tabii.com/account"),
        (["adobe"], "https://account.adobe.com/plans"),
        (["microsoft", "office 365", "xbox"], "https://account.microsoft.com/services"),
        (["playstation", "ps plus"], "https://www.playstation.com/account/subscriptions"),
        (["nintendo"], "https://accounts.nintendo.com"),
        (["duolingo"], "https://www.duolingo.com/settings/super"),
        (["headspace"], "https://www.headspace.com/settings/subscription"),
        (["canva"], "https://www.canva.com/settings/billing-and-teams"),
        (["figma"], "https://www.figma.com/settings"),
        (["twitch"], "https://www.twitch.tv/subscriptions"),
        (["x premium", "twitter"], "https://x.com/settings/subscriptions"),
        (["tinder"], "https://tinder.com/app/settings"),
        (["deezer"], "https://www.deezer.com/account/subscription"),
        (["audible"], "https://www.audible.com/account/overview"),
        (["kindle"], "https://www.amazon.com/mc")
    ]

    static func url(forServiceNamed name: String) -> URL? {
        let normalized = name
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
        guard !normalized.isEmpty else { return nil }
        for entry in entries where entry.keywords.contains(where: { normalized.contains($0) }) {
            return URL(string: entry.url)
        }
        return nil
    }
}
