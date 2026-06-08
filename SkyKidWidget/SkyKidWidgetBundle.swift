//
//  SkyKidWidgetBundle.swift
//  SkyKidWidget
//
//  Created by Northarion on 05.06.2026.
//

import WidgetKit
import SwiftUI

@main
struct SkyKidWidgetBundle: WidgetBundle {
    var body: some Widget {
        ClothingStatusWidget()
        ClothingStatusLockScreenWidget()
    }
}
