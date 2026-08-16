import UIKit

/// v5 7-day week strip (screen 06): one cell per day (r14). Today = accent
/// fill with `accentOnFill` content; days with renewals show an accent dot.
final class SublyWeekStrip: UIView {

    struct Day {
        let weekdayLetter: String
        let dayNumber: String
        let isToday: Bool
        let hasRenewal: Bool
        /// e.g. "Friday July 4, 2 renewals" for VoiceOver.
        let accessibilityLabel: String
    }

    private let stack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    func configure(days: [Day]) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for day in days {
            stack.addArrangedSubview(makeCell(for: day))
        }
    }

    private func makeCell(for day: Day) -> UIView {
        let cell = UIView()
        cell.layer.cornerRadius = 14
        cell.layer.cornerCurve = .continuous
        cell.backgroundColor = day.isToday
            ? DesignSystem.Colors.accent
            : DesignSystem.Colors.surface
        if !day.isToday {
            cell.layer.borderWidth = 1
            cell.layer.borderColor = DesignSystem.Colors.hairline.cgColor
        }

        let weekday = UILabel()
        weekday.text = day.weekdayLetter
        weekday.font = DesignSystem.Typography.tabLabel
        weekday.textColor = day.isToday
            ? DesignSystem.Colors.accentOnFill.withAlphaComponent(0.7)
            : DesignSystem.Colors.textTertiary
        weekday.textAlignment = .center

        let number = UILabel()
        number.text = day.dayNumber
        number.font = DesignSystem.Typography.scaled(15, weight: .bold, relativeTo: .body, tabular: true)
        number.textColor = day.isToday
            ? DesignSystem.Colors.accentOnFill
            : DesignSystem.Colors.textPrimary
        number.textAlignment = .center

        let dot = UIView()
        dot.backgroundColor = day.isToday
            ? DesignSystem.Colors.accentOnFill
            : DesignSystem.Colors.accent
        dot.layer.cornerRadius = 2
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.isHidden = !day.hasRenewal
        NSLayoutConstraint.activate([
            dot.widthAnchor.constraint(equalToConstant: 4),
            dot.heightAnchor.constraint(equalToConstant: 4)
        ])

        let column = UIStackView(arrangedSubviews: [weekday, number, dot])
        column.axis = .vertical
        column.alignment = .center
        column.spacing = 3
        column.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(column)
        NSLayoutConstraint.activate([
            column.centerXAnchor.constraint(equalTo: cell.centerXAnchor),
            column.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            cell.heightAnchor.constraint(equalToConstant: 66)
        ])

        cell.isAccessibilityElement = true
        cell.accessibilityLabel = day.accessibilityLabel
        if day.isToday { cell.accessibilityTraits = .selected }
        return cell
    }
}
