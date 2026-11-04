import SwiftUI

/// Lo storico mese per mese: un colpo d'occhio su cosa hai fatto, giorno per giorno.
struct HabitCalendar: View {
    let habit: Habit

    var body: some View {
        let log = Log(habit)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("Calendario")).font(.cozy(28, .bold)).foregroundStyle(Theme.ink)
                    Text(habit.title).font(.cozy(15, .medium)).foregroundStyle(Theme.muted)
                }
                HStack(spacing: 10) {
                    tile(log.count(in: Clock.calendar.dateInterval(of: .month, for: Clock.now)), L("Questo mese"))
                    tile(log.count(in: nil), L("In tutto"))
                }
                legend(log)
                ForEach(log.months, id: \.self) { month($0, log) }
            }
            .padding(.horizontal, 18)
            .padding(.top, 24)
            .padding(.bottom, 30)
        }
    }

    private var unit: String {
        if habit.kind == .quit { return L("Giorni riusciti") }
        return habit.rhythm.isWeekly ? L("Volte fatte") : L("Giorni fatti")
    }

    private func tile(_ value: Int, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)").font(.cozy(26, .bold)).foregroundStyle(Theme.ink)
            Text(unit).font(.cozy(13, .semibold)).foregroundStyle(Theme.ink.opacity(0.75))
            Text(label).font(.cozy(12, .medium)).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(card)
    }

    private func legend(_ log: Log) -> some View {
        HStack(spacing: 14) {
            ForEach(log.legend, id: \.0) { mark, label in
                HStack(spacing: 6) {
                    Circle().fill(mark.fill).frame(width: 11, height: 11)
                    Text(label).font(.cozy(12, .medium)).foregroundStyle(Theme.muted)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func month(_ start: Date, _ log: Log) -> some View {
        let rows = log.rows(start)
        return VStack(alignment: .leading, spacing: 10) {
            Text(Log.monthName(start)).font(.cozy(17, .bold)).foregroundStyle(Theme.ink)
            HStack(spacing: 0) {
                ForEach(Array(Log.weekdays.enumerated()), id: \.offset) { _, s in
                    Text(s).font(.cozy(11, .semibold)).foregroundStyle(Theme.muted).frame(maxWidth: .infinity)
                }
                if habit.rhythm.isWeekly { Color.clear.frame(width: 36, height: 1) }
            }
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, day in
                        cell(day, start, log).frame(maxWidth: .infinity)
                    }
                    if habit.rhythm.isWeekly { weekCount(row, log) }
                }
            }
        }
        .padding(14)
        .background(card)
    }

    /// Come `surface`, ma l'ombra resta sotto la scheda e non finisce sui cerchi dei giorni.
    private var card: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Theme.paper)
            .shadow(color: .black.opacity(0.07), radius: 14, y: 5)
    }

    private func cell(_ day: Int?, _ start: Date, _ log: Log) -> some View {
        Group {
            if let day {
                let mark = log.mark(day)
                let future = day > Clock.today
                Text("\(day - Clock.day(start) + 1)")
                    .font(.cozy(13, .semibold))
                    .foregroundStyle(mark.filled ? .white : Theme.ink.opacity(future ? 0.25 : mark == .none ? 0.45 : 0.8))
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(mark.fill))
                    .overlay(Circle().strokeBorder(Theme.violet, lineWidth: 2).opacity(day == Clock.today ? 1 : 0))
            } else {
                Color.clear.frame(width: 34, height: 34)
            }
        }
    }

    private func weekCount(_ row: [Int?], _ log: Log) -> some View {
        let target = habit.rhythm.target
        let n = log.weekCount(row)
        return Text(n.map { "\($0)/\(target)" } ?? "")
            .font(.cozy(12, .bold))
            .foregroundStyle(n ?? 0 >= target ? Theme.green : Theme.muted)
            .frame(width: 36, alignment: .trailing)
    }
}

private enum Mark {
    case none, done, partial, bad, missed

    var fill: Color {
        switch self {
        case .none: return .clear
        case .done: return Theme.green
        case .partial: return Theme.green.opacity(0.35)
        case .bad: return Theme.red
        case .missed: return Theme.track
        }
    }

    var filled: Bool { self == .done || self == .bad }
}

/// Le risposte dell'abitudine raccolte per giorno.
private struct Log {
    let habit: Habit
    let first: Int
    let good: [Int: Int]
    let bad: Set<Int>

    init(_ h: Habit) {
        habit = h
        first = Clock.day(h.created)
        good = Dictionary(grouping: h.goodAnswers, by: \.day).mapValues(\.count)
        bad = Set(h.answers.filter { !$0.good }.map(\.day) + h.relapses.map { Clock.day($0.at) })
    }

    func mark(_ day: Int) -> Mark {
        guard day >= first, day <= Clock.today else { return .none }
        let n = good[day] ?? 0
        let past = day < Clock.today
        if habit.kind == .quit {
            if bad.contains(day) { return .bad }
            return n > 0 ? .done : past ? .missed : .none
        }
        if n >= habit.rhythm.target || (habit.rhythm.isWeekly && n > 0) { return .done }
        if n > 0 { return .partial }
        return past && !habit.rhythm.isWeekly ? .missed : .none
    }

    /// Giorni fatti (o volte, per chi va a settimana) nel periodo; `nil` vuol dire da sempre.
    func count(in period: DateInterval?) -> Int {
        let days = (first...max(first, Clock.today)).filter { d in
            period.map { $0.contains(Clock.startOfDay(d).addingTimeInterval(3600)) } ?? true
        }
        if habit.rhythm.isWeekly { return days.reduce(0) { $0 + (good[$1] ?? 0) } }
        return days.filter { mark($0) == .done }.count
    }

    func weekCount(_ row: [Int?]) -> Int? {
        guard let start = row.compactMap({ $0 }).first,
              let w = Clock.calendar.dateInterval(of: .weekOfYear, for: Clock.startOfDay(start).addingTimeInterval(3600)),
              Clock.day(w.start) <= Clock.today, Clock.day(w.end) > first else { return nil }
        let week = Habit.week(w.start)
        return habit.goodAnswers.filter { Habit.week($0.at) == week }.count
    }

    var legend: [(Mark, String)] {
        if habit.kind == .quit { return [(.done, L("Pulito")), (.bad, L("Ricaduta")), (.missed, L("Senza risposta"))] }
        switch habit.rhythm {
        case .daily: return [(.done, L("Fatto")), (.missed, L("Non fatto"))]
        case .perDay: return [(.done, L("Fatto")), (.partial, L("In parte")), (.missed, L("Non fatto"))]
        case .weekly: return [(.done, L("Fatto"))]
        }
    }

    /// Dal mese in corso al primo, il più recente in alto.
    var months: [Date] {
        let cal = Clock.calendar
        guard var m = cal.dateInterval(of: .month, for: Clock.now)?.start,
              let stop = cal.dateInterval(of: .month, for: habit.created)?.start else { return [] }
        var list: [Date] = []
        while m >= stop {
            list.append(m)
            guard let prev = cal.date(byAdding: .month, value: -1, to: m) else { break }
            m = prev
        }
        return list
    }

    /// Le settimane del mese, con i buchi prima del primo giorno e dopo l'ultimo.
    func rows(_ start: Date) -> [[Int?]] {
        let cal = Clock.calendar
        let count = cal.range(of: .day, in: .month, for: start)?.count ?? 30
        let lead = (cal.component(.weekday, from: start) - cal.firstWeekday + 7) % 7
        let day0 = Clock.day(start)
        var cells: [Int?] = Array(repeating: nil, count: lead) + (0..<count).map { day0 + $0 }
        while cells.count % 7 != 0 { cells.append(nil) }
        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<$0 + 7]) }
    }

    static var weekdays: [String] {
        var cal = Clock.calendar
        cal.locale = Locale(identifier: Lang.code)
        let s = cal.veryShortStandaloneWeekdaySymbols
        return (0..<7).map { s[(Clock.calendar.firstWeekday - 1 + $0) % 7] }
    }

    static func monthName(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: Lang.code)
        f.setLocalizedDateFormatFromTemplate(date.isSameYear ? "LLLL" : "LLLL yyyy")
        let s = f.string(from: date)
        return s.prefix(1).uppercased() + s.dropFirst()
    }
}

private extension Date {
    var isSameYear: Bool { Clock.calendar.component(.year, from: self) == Clock.calendar.component(.year, from: Clock.now) }
}
