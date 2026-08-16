import UIKit

/// v5 month calendar grid (screen 10): MON–SUN header + week rows.
/// Today = accent-filled cell with dark text; renewal days = accent-bordered
/// cell with an accent dot; days outside the month are blank.
final class SublyMonthGrid: UIView {

    struct Day {
        let dayNumber: String
        let isInMonth: Bool
        let isToday: Bool
        let hasRenewal: Bool
        let accessibilityLabel: String?
    }

    private let headerRow = UIStackView()
    private let weeksStack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        headerRow.axis = .horizontal
        headerRow.distribution = .fillEqually

        weeksStack.axis = .vertical
        weeksStack.spacing = 6

        let column = UIStackView(arrangedSubviews: [headerRow, weeksStack])
        column.axis = .vertical
        column.spacing = DesignSystem.Spacing.sm
        column.translatesAutoresizingMaskIntoConstraints = false
        addSubview(column)
        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: topAnchor),
            column.leadingAnchor.constraint(equalTo: leadingAnchor),
            column.trailingAnchor.constraint(equalTo: trailingAnchor),
            column.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    /// `weekdayLetters` are the localized MON–SUN symbols in display order;
    /// `days` flow row-major, a multiple of 7.
    func configure(weekdayLetters: [String], days: [Day]) {
        headerRow.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for letter in weekdayLetters {
            let label = UILabel()
            label.text = letter
            label.font = DesignSystem.Typography.tabLabel
            label.textColor = DesignSystem.Colors.textTertiary
            label.textAlignment = .center
            label.adjustsFontForContentSizeCategory = true
            headerRow.addArrangedSubview(label)
        }

        weeksStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for weekStart in stride(from: 0, to: days.count, by: 7) {
            let row = UIStackView()
            row.axis = .horizontal
            row.distribution = .fillEqually
            row.spacing = 6
            for index in weekStart..<min(weekStart + 7, days.count) {
                row.addArrangedSubview(makeCell(days[index]))
            }
            weeksStack.addArrangedSubview(row)
        }
    }

    private func makeCell(_ day: Day) -> UIView {
        let cell = UIView()
        cell.layer.cornerRadius = 10
        cell.layer.cornerCurve = .continuous
        cell.heightAnchor.constraint(greaterThanOrEqualToConstant: 40).isActive = true

        guard day.isInMonth else { return cell }

        let numberLabel = UILabel()
        numberLabel.text = day.dayNumber
        numberLabel.font = DesignSystem.Typography.subhead
        numberLabel.textAlignment = .center
        numberLabel.adjustsFontForContentSizeCategory = true
        numberLabel.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(numberLabel)

        let dot = UIView()
        dot.backgroundColor = DesignSystem.Colors.accent
        dot.layer.cornerRadius = 2
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.isHidden = !(day.hasRenewal && !day.isToday)
        cell.addSubview(dot)

        NSLayoutConstraint.activate([
            numberLabel.centerXAnchor.constraint(equalTo: cell.centerXAnchor),
            numberLabel.centerYAnchor.constraint(equalTo: cell.centerYAnchor, constant: -2),
            dot.centerXAnchor.constraint(equalTo: cell.centerXAnchor),
            dot.topAnchor.constraint(equalTo: numberLabel.bottomAnchor, constant: 1),
            dot.widthAnchor.constraint(equalToConstant: 4),
            dot.heightAnchor.constraint(equalToConstant: 4)
        ])

        if day.isToday {
            cell.backgroundColor = DesignSystem.Colors.accent
            numberLabel.textColor = DesignSystem.Colors.accentOnFill
            numberLabel.font = DesignSystem.Typography.scaled(13, weight: .bold, relativeTo: .subheadline)
        } else if day.hasRenewal {
            cell.layer.borderWidth = 1.5
            cell.layer.borderColor = DesignSystem.Colors.accent.cgColor
            numberLabel.textColor = DesignSystem.Colors.textPrimary
        } else {
            numberLabel.textColor = DesignSystem.Colors.textSecondary
        }

        cell.isAccessibilityElement = day.accessibilityLabel != nil
        cell.accessibilityLabel = day.accessibilityLabel
        return cell
    }

    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        guard traitCollection.hasDifferentColorAppearance(comparedTo: previous) else { return }
        // Border colors are CGColor — refresh by walking renewal cells.
        for row in weeksStack.arrangedSubviews.compactMap({ $0 as? UIStackView }) {
            for cell in row.arrangedSubviews where cell.layer.borderWidth > 0 {
                cell.layer.borderColor = DesignSystem.Colors.accent.cgColor
            }
        }
    }
}
