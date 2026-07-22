import Foundation

// MARK: - Transport presentation

extension TransportMode {
    var walkLabel: String {
        switch self {
        case .walking:         return "Пешком"
        case .pramBassinette:  return "Люлька"
        case .pushchairSeat:   return "Прогулочная коляска"
        case .carrier:         return "Слинг / эргорюкзак"
        case .carSeat:         return "Автокресло"
        }
    }

    var walkSystemImage: String {
        switch self {
        case .walking:         return "figure.walk"
        case .pramBassinette:  return "stroller"
        case .pushchairSeat:   return "stroller"
        case .carrier:         return "figure.and.child.holdinghands"
        case .carSeat:         return "car.fill"
        }
    }
}
