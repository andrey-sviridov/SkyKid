import Foundation

// MARK: - Transport presentation

extension TransportMode {
    var walkLabel: String {
        switch self {
        case .walking:         return L10n.text("Пешком")
        case .pramBassinette:  return L10n.text("Люлька")
        case .pushchairSeat:   return L10n.text("Прогулочная коляска")
        case .carrier:         return L10n.text("Слинг / эргорюкзак")
        case .carSeat:         return L10n.text("Автокресло")
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
