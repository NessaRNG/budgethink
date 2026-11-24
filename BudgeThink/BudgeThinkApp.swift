//
//  BudgeThinkApp.swift
//  BudgeThink
//
//  Created by MacBook on 18/05/25.
//

import SwiftUI

@main
struct BudgeThinkApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(appState)
        }
        .modelContainer(for: [Plan.self, Budget.self])
    }
}
