//
//  EyeCareApp.swift
//  EyeCare
//
//  Created by Nguyen Mai Nhat Anh on 2025/6/4.
//

import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var timerManager: TimerManager
    
    var body: some View {
        VStack {
            Text("EyeCare")
                .font(.headline)
            Text(timerManager.isBreakTime ? "Break Time" : "Work Time")
                .font(.subheadline)
            Text(timerManager.isBreakTime ? "\(timerManager.timeRemaining)s remaining" : "\(timerManager.timeRemaining / 60)m remaining")
                .font(.caption)
        }
        .padding()
        .frame(width: 200)
    }
}

@main
struct EyeCareApp: App {
    @StateObject private var timerManager = TimerManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(timerManager)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 300, height: 200)
        
        MenuBarExtra("EyeCare", systemImage: "eye") {
            MenuBarView()
                .environmentObject(timerManager)
        }
        .menuBarExtraStyle(.window)
    }
}
