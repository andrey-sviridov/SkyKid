import Foundation

struct TabBarItem: Identifiable {
    let tag: Int
    let title: String
    let systemImage: String
    var id: Int { tag }
}
