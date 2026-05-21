import Foundation
import SwiftData

@Model
final class modelHorasDisponiveis {
    @Attribute(.unique) var id: UUID
    var domingo: Int
    var segunda: Int
    var terca: Int
    var quarta: Int
    var quinta: Int
    var sexta: Int
    var sabado: Int
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        domingo: Int = 2,
        segunda: Int = 3,
        terca: Int = 2,
        quarta: Int = 1,
        quinta: Int = 2,
        sexta: Int = 1,
        sabado: Int = 0,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.domingo = Self.hoursToMinutes(domingo)
        self.segunda = Self.hoursToMinutes(segunda)
        self.terca = Self.hoursToMinutes(terca)
        self.quarta = Self.hoursToMinutes(quarta)
        self.quinta = Self.hoursToMinutes(quinta)
        self.sexta = Self.hoursToMinutes(sexta)
        self.sabado = Self.hoursToMinutes(sabado)
        self.updatedAt = updatedAt
    }
}

extension modelHorasDisponiveis {
    func minutes(for day: AvailableWeekday) -> Int {
        switch day {
        case .domingo:
            return Self.normalizedStoredMinutes(domingo)
        case .segunda:
            return Self.normalizedStoredMinutes(segunda)
        case .terca:
            return Self.normalizedStoredMinutes(terca)
        case .quarta:
            return Self.normalizedStoredMinutes(quarta)
        case .quinta:
            return Self.normalizedStoredMinutes(quinta)
        case .sexta:
            return Self.normalizedStoredMinutes(sexta)
        case .sabado:
            return Self.normalizedStoredMinutes(sabado)
        }
    }

    func horas(for day: AvailableWeekday) -> Int {
        Int((Double(minutes(for: day)) / 60).rounded())
    }

    func setHoras(_ value: Int, for day: AvailableWeekday) {
        setMinutes(Self.hoursToMinutes(value), for: day)
    }

    func setMinutes(_ value: Int, for day: AvailableWeekday) {
        let clampedValue = Self.clampedMinutes(value)
        switch day {
        case .domingo:
            domingo = clampedValue
        case .segunda:
            segunda = clampedValue
        case .terca:
            terca = clampedValue
        case .quarta:
            quarta = clampedValue
        case .quinta:
            quinta = clampedValue
        case .sexta:
            sexta = clampedValue
        case .sabado:
            sabado = clampedValue
        }

        updatedAt = .now
    }

    var weeklyTotalMinutes: Int {
        AvailableWeekday.allCases.reduce(0) { partialResult, day in
            partialResult + minutes(for: day)
        }
    }

    static func formattedTime(minutes: Int) -> String {
        let clamped = clampedMinutes(minutes)
        let hours = clamped / 60
        let mins = clamped % 60

        if mins == 0 {
            return "\(hours)h"
        }

        return "\(hours)h \(mins)min"
    }

    private static func normalizedStoredMinutes(_ value: Int) -> Int {
        if value <= 24 {
            return hoursToMinutes(value)
        }

        return clampedMinutes(value)
    }

    private static func hoursToMinutes(_ value: Int) -> Int {
        clampedMinutes(value * 60)
    }

    private static func clampedMinutes(_ value: Int) -> Int {
        min(max(value, 0), 24 * 60)
    }
}

enum AvailableWeekday: CaseIterable, Identifiable, Hashable {
    case domingo
    case segunda
    case terca
    case quarta
    case quinta
    case sexta
    case sabado

    var id: Self { self }

    var shortTitle: String {
        switch self {
        case .domingo:
            return "dom"
        case .segunda:
            return "seg"
        case .terca:
            return "ter"
        case .quarta:
            return "qua"
        case .quinta:
            return "qui"
        case .sexta:
            return "sex"
        case .sabado:
            return "sab"
        }
    }
}
