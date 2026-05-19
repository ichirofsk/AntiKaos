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
        self.domingo = Self.clampedHour(domingo)
        self.segunda = Self.clampedHour(segunda)
        self.terca = Self.clampedHour(terca)
        self.quarta = Self.clampedHour(quarta)
        self.quinta = Self.clampedHour(quinta)
        self.sexta = Self.clampedHour(sexta)
        self.sabado = Self.clampedHour(sabado)
        self.updatedAt = updatedAt
    }
}

extension modelHorasDisponiveis {
    func horas(for day: AvailableWeekday) -> Int {
        switch day {
        case .domingo:
            return domingo
        case .segunda:
            return segunda
        case .terca:
            return terca
        case .quarta:
            return quarta
        case .quinta:
            return quinta
        case .sexta:
            return sexta
        case .sabado:
            return sabado
        }
    }

    func setHoras(_ value: Int, for day: AvailableWeekday) {
        let clampedValue = Self.clampedHour(value)

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

    private static func clampedHour(_ value: Int) -> Int {
        min(max(value, 0), 24)
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
