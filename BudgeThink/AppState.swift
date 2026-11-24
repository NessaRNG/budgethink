//
//  AppState.swift
//  BudgeThink
//
//  Created by MacBook on 18/05/25.
//

import Foundation
import SwiftUI

final class AppState: ObservableObject {
    @Published var selectedDate: Date = Date()
    
    var bulanTahunKey: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "id_ID")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedDate)
    }
}
