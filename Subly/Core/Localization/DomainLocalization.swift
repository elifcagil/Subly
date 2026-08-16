import Foundation

extension BillingCycle {
    var localizedName: String {
        switch self {
        case .weekly: return Strings.BillingCycle.weekly
        case .monthly: return Strings.BillingCycle.monthly
        case .quarterly: return Strings.BillingCycle.quarterly
        case .yearly: return Strings.BillingCycle.yearly
        case .custom: return Strings.BillingCycle.custom
        }
    }
}

extension Category {
    var localizedName: String {
        switch name {
        case "Streaming": return Strings.Category.streaming
        case "Music": return Strings.Category.music
        case "Productivity": return Strings.Category.productivity
        case "News": return Strings.Category.news
        case "Cloud": return Strings.Category.cloud
        case "Fitness": return Strings.Category.fitness
        case "Other": return Strings.Category.other
        default: return name
        }
    }
}
