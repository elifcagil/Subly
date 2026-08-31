import Foundation

enum Strings {

    enum Common {
        static var save: String { L("common.save") }
        static var cancel: String { L("common.cancel") }
        static var delete: String { L("common.delete") }
        static var close: String { L("common.close") }
        static var ok: String { L("common.ok") }
        static var edit: String { L("common.edit") }
        static var archive: String { L("common.archive") }
        static var upgrade: String { L("common.upgrade") }
        static var signIn: String { L("common.sign_in") }
        static var signOut: String { L("common.sign_out") }
        static var retry: String { L("common.retry") }
        static var somethingWentWrong: String { L("common.something_went_wrong") }
    }

    enum Tabs {
        static var dashboard: String { L("tabs.dashboard") }
        static var subscriptions: String { L("tabs.subscriptions") }
        static var timeline: String { L("tabs.timeline") }
        static var insights: String { L("tabs.insights") }
        static var settings: String { L("tabs.settings") }
        static var search: String { L("tabs.search") }
    }

    enum Onboarding {
        static var next: String { L("onboarding.next") }
        static var skip: String { L("onboarding.skip") }
        static var getStarted: String { L("onboarding.get_started") }
        static var allowNotifications: String { L("onboarding.allow_notifications") }

        static var trackingTitle: String { L("onboarding.tracking.title") }
        static var trackingMessage: String { L("onboarding.tracking.message") }
        static var renewalsTitle: String { L("onboarding.renewals.title") }
        static var renewalsMessage: String { L("onboarding.renewals.message") }
        static var insightsTitle: String { L("onboarding.insights.title") }
        static var insightsMessage: String { L("onboarding.insights.message") }
        static var notificationsTitle: String { L("onboarding.notifications.title") }
        static var notificationsMessage: String { L("onboarding.notifications.message") }

        // v5 single-screen onboarding (screen 01).
        static var headline: String { L("onboarding.headline") }
        static var subcopy: String { L("onboarding.subcopy") }
        static var addFirst: String { L("onboarding.add_first") }
        static var sampleData: String { L("onboarding.sample_data") }
    }

    enum EmptyState {
        static var title: String { L("empty.title") }
        static var message: String { L("empty.message") }
        static var add: String { L("empty.add") }
        static var sample: String { L("empty.sample") }
    }

    enum Dashboard {
        static var title: String { L("dashboard.title") }
        static var monthlyTotal: String { L("dashboard.monthly_total") }
        static var activeSubscriptionsSingular: String { L("dashboard.active_one") }
        static func activeSubscriptions(_ count: Int) -> String {
            count == 1
                ? "1 \(activeSubscriptionsSingular)"
                : "\(count) \(L("dashboard.active_other"))"
        }
        static var upcomingHeader: String { L("dashboard.upcoming_header") }
        static var activeSubs: String { L("dashboard.active_subs") }
        static var seeAll: String { L("dashboard.see_all") }
        static var thisMonth: String { L("dashboard.this_month") }
        static var nextSevenDays: String { L("dashboard.next_seven_days") }
        static var byCategory: String { L("dashboard.by_category") }
        /// "%@ %d%% vs %@" — arrow symbol, percent, previous month name.
        static var deltaFormat: String { L("dashboard.delta_format") }
        static func activeCount(_ count: Int) -> String {
            String(format: L("dashboard.active_count_format"), count)
        }
        static func yearlyShort(_ amountText: String) -> String {
            String(format: L("dashboard.yearly_short_format"), amountText)
        }
        static func yearly(_ amountText: String) -> String {
            String(format: L("dashboard.yearly_format"), amountText)
        }
        static func dueCaption(_ countText: String) -> String {
            String(format: L("dashboard.due_caption_format"), countText)
        }
        static var emptyTitle: String { L("dashboard.empty_title") }
        static var emptyMessage: String { L("dashboard.empty_message") }
        static var addAccessibility: String { L("dashboard.add_accessibility") }
        static func pressureCaption(_ currencyCode: String) -> String {
            String(format: L("dashboard.pressure_caption_format"), currencyCode)
        }
    }

    enum Splash {
        static var tagline: String { L("splash.tagline") }
        static var preparing: String { L("splash.preparing") }
    }

    enum Registration {
        static var headline: String { L("registration.headline") }
        static var subcopy: String { L("registration.subcopy") }
        static var trust1Title: String { L("registration.trust1_title") }
        static var trust1Body: String { L("registration.trust1_body") }
        static var trust2Title: String { L("registration.trust2_title") }
        static var trust2Body: String { L("registration.trust2_body") }
        static var trust3Title: String { L("registration.trust3_title") }
        static var trust3Body: String { L("registration.trust3_body") }
        static var yourID: String { L("registration.your_id") }
        static var copied: String { L("registration.copied") }
        static var continueButton: String { L("registration.continue") }
        static var legal: String { L("registration.legal") }
        static var registeredTitle: String { L("registering.title") }
        static var takingToDashboard: String { L("registering.taking") }
        static var failedMessage: String { L("registering.failed") }
    }

    enum FinancialLoad {
        static var title: String { L("financial_load.title") }
        static var horizon24h: String { L("financial_load.horizon_24h") }
        static var horizon7d: String { L("financial_load.horizon_7d") }
        static var horizon30d: String { L("financial_load.horizon_30d") }
        static func horizonCustom(_ days: Int) -> String {
            String(format: L("financial_load.horizon_custom_format"), days)
        }
        static var empty24h: String { L("financial_load.empty_24h") }
        static var empty7d: String { L("financial_load.empty_7d") }
        static var empty30d: String { L("financial_load.empty_30d") }
        static var emptyTitle: String { L("financial_load.empty_title") }
        static var emptyMessage: String { L("financial_load.empty_message") }
        static func renewals(_ count: Int) -> String {
            count == 1
                ? L("financial_load.renewals_one")
                : String(format: L("financial_load.renewals_other_format"), count)
        }
        static func toneLabel(_ tone: FinancialLoadWindow.Tone) -> String {
            L("financial_load.tone.\(tone.localizationSuffix)")
        }
        static func heaviestDay(date: String, amount: String) -> String {
            String(format: L("financial_load.heaviest_day_format"), date, amount)
        }
    }

    enum Notifications {
        // Renewal — Tier 1 (v5 screen 11: specific title, calm actionable body)
        static func renewalTitleToday(name: String, amount: String) -> String {
            String(format: L("notifications.renewal.title_today_format"), name, amount)
        }
        static func renewalTitleTomorrow(name: String, amount: String) -> String {
            String(format: L("notifications.renewal.title_tomorrow_format"), name, amount)
        }
        static func renewalTitleInDays(name: String, days: Int, amount: String) -> String {
            String(format: L("notifications.renewal.title_days_format"), name, days, amount)
        }
        static var renewalBody: String { L("notifications.renewal.body") }

        // Smart — Tier 2
        static var smartWeeklyTitle: String { L("notifications.smart.weekly.title") }
        static func smartWeekly(count: Int) -> String {
            count == 1
                ? L("notifications.smart.weekly.body_one")
                : String(format: L("notifications.smart.weekly.body_other_format"), count)
        }
        static var smartHeavyTitle: String { L("notifications.smart.heavy.title") }
        static func smartHeavyBody(count: Int) -> String {
            String(format: L("notifications.smart.heavy.body_format"), count)
        }
        static var smartNewStartsTitle: String { L("notifications.smart.new_starts.title") }
        static func smartNewStartsBody(count: Int) -> String {
            count == 1
                ? L("notifications.smart.new_starts.body_one")
                : String(format: L("notifications.smart.new_starts.body_other_format"), count)
        }

        // Awareness — Tier 3
        static var awarenessHorizonTitle: String { L("notifications.awareness.horizon.title") }
        static func awarenessHorizonBody(amount: String, days: Int) -> String {
            String(format: L("notifications.awareness.horizon.body_format"), amount, days)
        }
        static var awarenessPeakTitle: String { L("notifications.awareness.peak.title") }
        static func awarenessPeakBody(date: String, amount: String) -> String {
            String(format: L("notifications.awareness.peak.body_format"), date, amount)
        }
    }

    enum SubscriptionList {
        static var title: String { L("subscription_list.title") }
        static var uncategorized: String { L("subscription_list.uncategorized") }
        static var emptyTitle: String { L("subscription_list.empty_title") }
        static var emptyMessage: String { L("subscription_list.empty_message") }
        static var failedTitle: String { L("subscription_list.failed_title") }
        static var deleteTitleFormat: String { L("subscription_list.delete_title_format") }
        static var deleteMessage: String { L("subscription_list.delete_message") }
        static var rowHint: String { L("subscription_list.row_hint") }
        static func renewsOn(_ dateText: String) -> String {
            String(format: L("subscription_list.renews_on_format"), dateText)
        }
    }

    enum SubscriptionDetail {
        static var nextRenewal: String { L("subscription_detail.next_renewal") }
        static var started: String { L("subscription_detail.started") }
        static var category: String { L("subscription_detail.category") }
        static var currency: String { L("subscription_detail.currency") }
        static var billingCycle: String { L("subscription_detail.billing_cycle") }
        static var yearlyCost: String { L("subscription_detail.yearly_cost") }
        static var reminder: String { L("subscription_detail.reminder") }
        static var dueToday: String { L("subscription_detail.due_today") }
        static var dueTomorrow: String { L("subscription_detail.due_tomorrow") }
        static var inDaysFormat: String { L("subscription_detail.in_days_format") }
        static var editDetails: String { L("subscription_detail.edit_details") }
        static var cancelPlan: String { L("subscription_detail.cancel_plan") }
        static var paidSoFar: String { L("subscription_detail.paid_so_far") }
        /// "%1$d payments since %2$@"
        static var paymentsSinceFormat: String { L("subscription_detail.payments_since_format") }
        /// "1 payment since %@"
        static var paymentSinceSingularFormat: String { L("subscription_detail.payment_since_singular_format") }
        static var remindMe: String { L("subscription_detail.remind_me") }
        static var oneWeekBefore: String { L("subscription_detail.one_week_before") }
        static var deleteTitle: String { L("subscription_detail.delete_title") }
        static var deleteMessage: String { L("subscription_detail.delete_message") }
        static var deleteButton: String { L("subscription_detail.delete_button") }
    }

    enum ReminderSheet {
        static var subtitle: String { L("reminder_sheet.subtitle") }
        static var done: String { L("reminder_sheet.done") }
    }

    enum AddEdit {
        static var addTitle: String { L("add_edit.add_title") }
        static var editTitle: String { L("add_edit.edit_title") }
        static var fieldName: String { L("add_edit.field_name") }
        static var fieldAmount: String { L("add_edit.field_amount") }
        static var fieldCurrency: String { L("add_edit.field_currency") }
        static var currencyHint: String { L("add_edit.currency_hint") }
        static var fieldBillingCycle: String { L("add_edit.field_billing_cycle") }
        static var fieldNextRenewal: String { L("add_edit.field_next_renewal") }
        static var fieldCategory: String { L("add_edit.field_category") }
        static var fieldReminders: String { L("add_edit.field_reminders") }
        static var fieldNotes: String { L("add_edit.field_notes") }
        /// "Adds %1$@/mo — your monthly total becomes %2$@"
        static var impactFormat: String { L("add_edit.impact_format") }
        static var namePlaceholder: String { L("add_edit.name_placeholder") }
        static var amountPlaceholder: String { L("add_edit.amount_placeholder") }
        static var categoryNone: String { L("add_edit.category_none") }
        static var categoryChoose: String { L("add_edit.category_choose") }
        static var reminderSameDay: String { L("add_edit.reminder_same_day") }
        static var reminderOneDay: String { L("add_edit.reminder_one_day") }
        static func reminderDays(_ days: Int) -> String {
            String(format: L("add_edit.reminder_days_format"), days)
        }
        static var couldNotSave: String { L("add_edit.could_not_save") }
        static var missingName: String { L("add_edit.missing_name") }
        static var invalidAmount: String { L("add_edit.invalid_amount") }
        static var saveHint: String { L("add_edit.save_hint") }
        static var cancelHint: String { L("add_edit.cancel_hint") }
    }

    enum Timeline {
        static var title: String { L("timeline.title") }
        static var emptyTitle: String { L("timeline.empty_title") }
        static var emptyMessage: String { L("timeline.empty_message") }
        /// "$71.46 due" — amount is styled accent by the view.
        static func due(_ amountText: String) -> String {
            String(format: L("timeline.due_format"), amountText)
        }
        static var week: String { L("timeline.week") }
        static var month: String { L("timeline.month") }
        static var paymentsThisMonth: String { L("timeline.payments_this_month") }
        static var previousMonth: String { L("timeline.previous_month") }
        static var nextMonth: String { L("timeline.next_month") }
    }

    enum Search {
        static var title: String { L("search.title") }
        static var placeholder: String { L("search.placeholder") }
        /// "2 results in Streaming"
        static func results(_ count: Int, in category: String) -> String {
            count == 1
                ? String(format: L("search.results_one_format"), category)
                : String(format: L("search.results_other_format"), count, category)
        }
        static var inNotes: String { L("search.in_notes") }
        static var promptTitle: String { L("search.prompt_title") }
        static var promptMessage: String { L("search.prompt_message") }
        static func noResults(_ query: String) -> String {
            String(format: L("search.no_results_format"), query)
        }
    }

    enum Insights {
        static var title: String { L("insights.title") }
        static var monthlyCaption: String { L("insights.monthly_caption") }
        static var yearlyCaption: String { L("insights.yearly_caption") }
        static var yearlyFootnote: String { L("insights.yearly_footnote") }
        static var biggestUpcoming: String { L("insights.biggest_upcoming") }
        static var whereItGoes: String { L("insights.where_it_goes") }
        static var nextFourWeeks: String { L("insights.next_four_weeks") }
        static var emptyTitle: String { L("insights.empty_title") }
        static var emptyMessage: String { L("insights.empty_message") }
        static var noBreakdown: String { L("insights.no_breakdown") }
        static var noRenewals: String { L("insights.no_renewals") }
        static func weekOf(_ dateText: String) -> String {
            String(format: L("insights.week_of_format"), dateText)
        }
        static func renewalsCount(_ count: Int) -> String {
            String(format: L(count == 1 ? "insights.renewals_one" : "insights.renewals_other"), count)
        }
    }

    enum Settings {
        static var title: String { L("settings.title") }
        static var sectionPlan: String { L("settings.section_plan") }
        static var sectionPreferences: String { L("settings.section_preferences") }
        static var sectionNotifications: String { L("settings.section_notifications") }
        static var sectionAbout: String { L("settings.section_about") }
        static var rowSublyPlus: String { L("settings.row_subly_plus") }
        static var rowAccount: String { L("settings.row_account") }
        static var rowCurrency: String { L("settings.row_currency") }
        static var rowAppearance: String { L("settings.row_appearance") }
        static var rowLanguage: String { L("settings.row_language") }
        static var rowPermission: String { L("settings.row_permission") }
        static var rowVersion: String { L("settings.row_version") }
        static var rowDeviceID: String { L("settings.row_device_id") }
        static var deviceIDCopied: String { L("settings.device_id_copied") }
        static var planActive: String { L("settings.plan_active") }
        static var planUpgrade: String { L("settings.plan_upgrade") }
        static var notSignedIn: String { L("settings.not_signed_in") }
        static var permissionEnabled: String { L("settings.permission_enabled") }
        static var permissionDisabled: String { L("settings.permission_disabled") }
        static var permissionNotRequested: String { L("settings.permission_not_requested") }
        static var permissionUnknown: String { L("settings.permission_unknown") }
        static var sectionAppearance: String { L("settings.section_appearance") }
        static var sectionLanguage: String { L("settings.section_language") }
        static var sectionCurrency: String { L("settings.section_currency") }
        static var currencyFooter: String { L("settings.currency_footer") }
        static var rowReminders: String { L("settings.row_reminders") }
        static var rowCalendarExport: String { L("settings.row_calendar_export") }
        static var rowNotifications: String { L("settings.row_notifications") }
        static var notificationsFooter: String { L("settings.notifications_footer") }
        static var dataFooter: String { L("settings.data_footer") }
        static var remindersOff: String { L("settings.reminders_off") }
        static var remindersSameDay: String { L("settings.reminders_same_day") }
        static var remindersOneDay: String { L("settings.reminders_one_day") }
        static var remindersDaysFormat: String { L("settings.reminders_days_format") }
        static func remindersDays(_ days: Int) -> String {
            String(format: L("settings.reminders_days_format"), days)
        }
        static var remindersPickerTitle: String { L("settings.reminders_picker_title") }
        static var remindersPickerFooter: String { L("settings.reminders_picker_footer") }
        static var calendarFooter: String { L("settings.calendar_footer") }
        static var calendarPermissionDenied: String { L("settings.calendar_permission_denied") }
        static func remindersSummaryTwo(_ a: String, _ b: String) -> String {
            String(format: L("settings.reminders_summary_two_format"), a, b)
        }
        static func remindersSummaryMore(_ a: String, _ b: String, extra: Int) -> String {
            String(format: L("settings.reminders_summary_more_format"), a, b, extra)
        }
    }

    enum Appearance {
        static var title: String { L("appearance.title") }
        static var automatic: String { L("appearance.automatic") }
        static var light: String { L("appearance.light") }
        static var dark: String { L("appearance.dark") }
        static var footer: String { L("appearance.footer") }
    }

    enum Language {
        static var title: String { L("language.title") }
        static var english: String { L("language.english") }
        static var turkish: String { L("language.turkish") }
        static var footer: String { L("language.footer") }
    }

    enum Paywall {
        static var navTitle: String { L("paywall.nav_title") }
        static var headline: String { L("paywall.headline") }
        static var subtitle: String { L("paywall.subtitle") }
        static var benefitInsights: String { L("paywall.benefit_insights") }
        static var benefitSync: String { L("paywall.benefit_sync") }
        static var benefitCalendar: String { L("paywall.benefit_calendar") }
        static var benefitFuture: String { L("paywall.benefit_future") }
        static var subscribe: String { L("paywall.subscribe") }
        static var restore: String { L("paywall.restore") }
        static var restoring: String { L("paywall.restoring") }
        static var alreadyPlus: String { L("paywall.already_plus") }
        static var unavailable: String { L("paywall.unavailable") }
        static var planMonthly: String { L("paywall.plan_monthly") }
        static var planYearly: String { L("paywall.plan_yearly") }
        static var bestValue: String { L("paywall.best_value") }
        static var trust: String { L("paywall.trust") }
        static func perMonth(_ price: String) -> String {
            String(format: L("paywall.per_month_format"), price)
        }
        static func pricePerPeriod(_ price: String, period: String) -> String {
            String(format: L("paywall.price_per_period_format"), price, period)
        }
    }

    enum Account {
        static var title: String { L("account.title") }
        static var planLabelFormat: String { L("account.plan_label_format") }
        static var free: String { L("account.free") }
        static var plus: String { L("account.plus") }
        static var signedInFallback: String { L("account.signed_in_fallback") }
    }

    enum BillingCycle {
        static var weekly: String { L("billing_cycle.weekly") }
        static var monthly: String { L("billing_cycle.monthly") }
        static var quarterly: String { L("billing_cycle.quarterly") }
        static var yearly: String { L("billing_cycle.yearly") }
        static var custom: String { L("billing_cycle.custom") }
    }

    enum Catalog {
        static var title: String { L("catalog.title") }
        static var sectionManual: String { L("catalog.section_manual") }
        static var sectionSuggested: String { L("catalog.section_suggested") }
        static var rowManual: String { L("catalog.row_manual") }
        static var emptyTitle: String { L("catalog.empty_title") }
        static var emptyMessage: String { L("catalog.empty_message") }
        static var searchPlaceholder: String { L("catalog.search_placeholder") }
    }

    enum List {
        static var searchPlaceholder: String { L("list.search_placeholder") }
        static var filterAll: String { L("list.filter_all") }
        static var filterActive: String { L("list.filter_active") }
        static var filterArchived: String { L("list.filter_archived") }
        static var sortButton: String { L("list.sort_button") }
        static var sortRenewalDate: String { L("list.sort_renewal_date") }
        static var sortAmount: String { L("list.sort_amount") }
        static var sortName: String { L("list.sort_name") }
        static var sortRecentlyAdded: String { L("list.sort_recently_added") }
        static var noMatchesTitle: String { L("list.no_matches_title") }
        static var noMatchesMessage: String { L("list.no_matches_message") }
        static var archiveAction: String { L("list.archive_action") }
        static var unarchiveAction: String { L("list.unarchive_action") }
    }

    enum Currency {
        static var title: String { L("currency.title") }
        static var sectionSuggested: String { L("currency.section_suggested") }
        static var sectionAll: String { L("currency.section_all") }
        static var searchPlaceholder: String { L("currency.search_placeholder") }
        static var emptyTitle: String { L("currency.empty_title") }
        static var emptyMessage: String { L("currency.empty_message") }
    }

    enum Category {
        static var streaming: String { L("category.streaming") }
        static var music: String { L("category.music") }
        static var productivity: String { L("category.productivity") }
        static var news: String { L("category.news") }
        static var cloud: String { L("category.cloud") }
        static var fitness: String { L("category.fitness") }
        static var other: String { L("category.other") }
    }
}
