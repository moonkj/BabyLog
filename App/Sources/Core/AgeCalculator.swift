import Foundation

enum AgeCalculator {

    static var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .current
        return c
    }()

    // MARK: - 임신 주수

    /// 임신 주수: edd 있으면 (edd - 280일) = 재태 0일 기준, 없으면 lmp 기준. 둘 다 nil이면 nil. (주, 일).
    static func pregnancyWeeks(lmp: Date?, edd: Date?, asOf: Date) -> (weeks: Int, days: Int)? {
        let today = calendar.startOfDay(for: asOf)

        let conceptionBase: Date
        if let edd = edd {
            // EDD 우선: EDD - 280일 = 재태 0일
            let eddStart = calendar.startOfDay(for: edd)
            guard let base = calendar.date(byAdding: .day, value: -280, to: eddStart) else { return nil }
            conceptionBase = base
        } else if let lmp = lmp {
            conceptionBase = calendar.startOfDay(for: lmp)
        } else {
            return nil
        }

        let components = calendar.dateComponents([.day], from: conceptionBase, to: today)
        guard let totalDays = components.day, totalDays >= 0 else { return nil }

        return (weeks: totalDays / 7, days: totalDays % 7)
    }

    // MARK: - D-Day

    /// edd - asOf 의 일수 (달력 startOfDay 기준). 지났으면 음수.
    static func dDayToBirth(edd: Date, asOf: Date) -> Int {
        let eddDay = calendar.startOfDay(for: edd)
        let today  = calendar.startOfDay(for: asOf)
        let components = calendar.dateComponents([.day], from: today, to: eddDay)
        return components.day ?? 0
    }

    // MARK: - 월령

    /// 월령: Calendar dateComponents([.month, .day]) (months, days).
    static func childAgeMonths(birthDate: Date, asOf: Date) -> (months: Int, days: Int) {
        let birth = calendar.startOfDay(for: birthDate)
        let today = calendar.startOfDay(for: asOf)
        let components = calendar.dateComponents([.month, .day], from: birth, to: today)
        return (months: components.month ?? 0, days: components.day ?? 0)
    }

    // MARK: - 생후 일수

    /// 생후 일수. 출생일 당일 = 1 (백일 = 100).
    static func dPlusDays(birthDate: Date, asOf: Date) -> Int {
        let birth = calendar.startOfDay(for: birthDate)
        let today = calendar.startOfDay(for: asOf)
        let components = calendar.dateComponents([.day], from: birth, to: today)
        return (components.day ?? 0) + 1
    }
}
