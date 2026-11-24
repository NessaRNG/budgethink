//
//  MainView.swift
//  BudgeThink
//
//  Created by MacBook on 18/05/25.
//

import SwiftUI

struct MainView: View {
    @StateObject private var appState = AppState()

    var body: some View {
        TabView {
            ContentView()
                .environmentObject(appState)
                .tabItem {
                    Label("Dashboard", systemImage: "house")
                }
            
            ReportView()
                .environmentObject(appState)
                .tabItem {
                    Label("Report", systemImage: "doc.text.magnifyingglass")
                }
        }
    }
}

#Preview {
    MainView()
        .environmentObject(AppState())
        .modelContainer(for: [Plan.self, Budget.self])
}
