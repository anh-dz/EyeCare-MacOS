import SwiftUI

struct ContentView: View {
    @EnvironmentObject var timerManager: TimerManager

    // We keep a single instance of BreakWindowController here
    @State private var breakWindowController: BreakWindowController?

    // Sidebar selection (unchanged)
    @State private var selection: SidebarTab? = .main

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                NavigationLink(value: SidebarTab.main) {
                    Label("Main", systemImage: "clock")
                }
                NavigationLink(value: SidebarTab.settings) {
                    Label("Settings", systemImage: "gear")
                }
                NavigationLink(value: SidebarTab.graph) {
                    Label("Graph", systemImage: "chart.bar.xaxis")
                }
            }
            .listStyle(SidebarListStyle())
            .frame(minWidth: 140)
        } detail: {
            Group {
                switch selection ?? .main {
                case .main:
                    MainView()
                        .environmentObject(timerManager)
                case .settings:
                    SettingsView()
                        .environmentObject(timerManager)
                case .graph:
                    GraphView()
                        .environmentObject(timerManager)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 330)
        .navigationSplitViewStyle(.balanced)
        .onChange(of: timerManager.isBreakTime) { _, newValue in
            if newValue {
                // Break just started: create & show our BreakWindowController
                let controller = BreakWindowController(timerManager: timerManager)
                controller.onClose = {
                    let wasRunning = timerManager.isRunning
                    timerManager.setBreakTime(false)
                    timerManager.setBreakShouldShowEnd(false)
                    if wasRunning {
                        timerManager.setTimeRemaining(timerManager.workDuration)
                        timerManager.startUsageTracking()
                        timerManager.toggleTimer() // stop
                        timerManager.toggleTimer() // start
                    }
                }
                breakWindowController = controller
                controller.show()
            } else {
                // Break just ended (user tapped "Close Break" or timer expired)
                breakWindowController?.hide()
                breakWindowController = nil
            }
        }
    }
}

enum SidebarTab: Hashable {
    case main
    case settings
    case graph
}

struct MainView: View {
    @EnvironmentObject var timerManager: TimerManager

    var body: some View {
        VStack(spacing: 24) {
            Text("EyeCare is running")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.top, 8)

            Text("Take a break every \(timerManager.workDuration / 60) minutes")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("Next break in: \(formatTimeRemaining())")
                .font(.title3)
                .fontWeight(.medium)
                .padding(.bottom, 8)

            HStack(spacing: 20) {
                Button(action: {
                    timerManager.toggleTimer()
                }) {
                    Image(systemName: timerManager.isRunning ? "stop.fill" : "play.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(timerManager.isRunning ? Color.red : Color.accentColor)
                        .padding(8)
                }
                .help(timerManager.isRunning ? "Stop" : "Start")

                Button(action: {
                    timerManager.skipToBreak()
                }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color.accentColor)
                        .padding(8)
                }
                .help("Skip to Break")
            }
            .padding(.top, 8)
        }
        .padding(32)
        .padding()
    }

    private func formatTimeRemaining() -> String {
        let totalSeconds = timerManager.timeRemaining
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct SettingsView: View {
    @EnvironmentObject var timerManager: TimerManager
    @State private var workMinutes: String = "20"
    @State private var breakSeconds: String = "20"
    @State private var showSaved = false
    @State private var workMinutesPrev: String = "20"
    @State private var breakSecondsPrev: String = "20"
    @State private var workMinutesError = false
    @State private var breakSecondsError = false

    let quickWorkOptions = [20, 30, 60] // in minutes
    let quickBreakOptions = [20, 30, 60] // in seconds

    var body: some View {
        VStack(spacing: 20) {
            Text("Settings")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.top, 8)
            Form {
                Section() {
                    HStack(spacing: 12) {
                        ForEach(quickWorkOptions, id: \.self) { min in
                            Button(action: {
                                workMinutes = String(min)
                                timerManager.setWorkDuration(minutes: min)
                                workMinutesPrev = String(min)
                                workMinutesError = false
                            }) {
                                Text("\(min) min")
                                    .font(.caption)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 12)
                                    .background((Int(workMinutes) == min) ? Color.accentColor.opacity(0.2) : Color.clear)
                                    .foregroundColor(.primary)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    HStack {
                        TextField("Work", text: $workMinutes, onEditingChanged: { editing in
                            if !editing {
                                validateWorkMinutes()
                            }
                        })
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 100)
                        .onChange(of: workMinutes) { oldValue, newValue in
                            if let minutes = Int(newValue), minutes >= 1, minutes <= 300 {
                                timerManager.setWorkDuration(minutes: minutes)
                                workMinutesPrev = newValue
                                workMinutesError = false
                            }
                        }
                        Text("minutes")
                    }
                    Text("(1-300 minutes)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    if workMinutesError {
                        Text("Invalid input time. Restored previous value.")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }

                Section() {
                    HStack(spacing: 12) {
                        ForEach(quickBreakOptions, id: \.self) { sec in
                            Button(action: {
                                breakSeconds = String(sec)
                                timerManager.setBreakDuration(seconds: sec)
                                breakSecondsPrev = String(sec)
                                breakSecondsError = false
                            }) {
                                Text("\(sec) sec")
                                    .font(.caption)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 12)
                                    .background((Int(breakSeconds) == sec) ? Color.accentColor.opacity(0.2) : Color.clear)
                                    .foregroundColor(.primary)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    HStack {
                        TextField("Break", text: $breakSeconds, onEditingChanged: { editing in
                            if !editing {
                                validateBreakSeconds()
                            }
                        })
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 100)
                        .onChange(of: breakSeconds) { oldValue, newValue in
                            if let seconds = Int(newValue), seconds >= 1, seconds <= 300 {
                                timerManager.setBreakDuration(seconds: seconds)
                                breakSecondsPrev = newValue
                                breakSecondsError = false
                            }
                        }
                        Text("seconds")
                    }
                    Text("(1-300 seconds)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    if breakSecondsError {
                        Text("Invalid input time. Restored previous value.")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }

                Button(action: {
                    timerManager.saveSettings()
                    showSaved = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showSaved = false
                    }
                }) {
                    Label("Save Settings", systemImage: "tray.and.arrow.down.fill")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
                .padding(.top)

                if showSaved {
                    Text("Settings saved!")
                        .foregroundColor(.green)
                        .font(.caption)
                }
            }
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.06), radius: 8, y: 2)
            .padding()
        }
        .onAppear {
            workMinutes = String(timerManager.workDuration / 60)
            workMinutesPrev = workMinutes
            breakSeconds = String(timerManager.breakDuration)
            breakSecondsPrev = breakSeconds
        }
        .padding()
        .id("settings-content")
    }

    private func validateWorkMinutes() {
        if let minutes = Int(workMinutes), minutes >= 1, minutes <= 300 {
            // valid
            workMinutesError = false
        } else {
            workMinutes = workMinutesPrev
            workMinutesError = true
            timerManager.setWorkDuration(minutes: Int(workMinutesPrev) ?? 20)
        }
    }

    private func validateBreakSeconds() {
        if let seconds = Int(breakSeconds), seconds >= 1, seconds <= 300 {
            // valid
            breakSecondsError = false
        } else {
            breakSeconds = breakSecondsPrev
            breakSecondsError = true
            timerManager.setBreakDuration(seconds: Int(breakSecondsPrev) ?? 20)
        }
    }
}

struct GraphView: View {
    @EnvironmentObject var timerManager: TimerManager
    @State private var usageData: [(date: Date, seconds: TimeInterval)] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("EyeCare App Usage (This Week)")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.top, 8)
            let today = Calendar.current.startOfDay(for: Date())
            let todayUsage = usageData.first(where: { Calendar.current.isDate($0.date, inSameDayAs: today) })?.seconds ?? 0
            Text("Today: \(formatTime(todayUsage))")
                .font(.headline)
            Button(action: {
                timerManager.resetAllUsageData()
                updateUsageData()
            }) {
                Label("Reset Graph Data", systemImage: "arrow.counterclockwise")
                    .font(.subheadline)
                    .foregroundColor(.red)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .padding(.bottom, 10)
            if !usageData.isEmpty {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray, lineWidth: 1.5)
                        .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(usageData, id: \ .date) { entry in
                            let date = entry.date
                            let seconds = entry.seconds
                            VStack {
                                Text("\(Int(seconds/60))m")
                                    .font(.caption2)
                                Rectangle()
                                    .fill(Color.blue)
                                    .frame(width: 20, height: barHeight(for: seconds))
                                Text(shortDate(date))
                                    .font(.caption2)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .frame(height: 120)
                .padding(.vertical, 4)
                .padding(.horizontal, 2)
            } else {
                Text("No usage data yet.")
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .padding()
        .onAppear {
            updateUsageData()
        }
        .onChange(of: timerManager.isRunning) { _, _ in
            updateUsageData()
        }
    }

    private func updateUsageData() {
        usageData = timerManager.getUsageForCurrentWeek()
    }

    private func barHeight(for seconds: TimeInterval) -> CGFloat {
        let maxSeconds = usageData.map { $0.seconds }.max() ?? 0
        if maxSeconds <= 0 { return 2 }
        if !seconds.isFinite || seconds <= 0 { return 2 }
        let height = CGFloat(seconds / maxSeconds) * 80
        return height.isFinite && height > 0 ? height : 2
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        return String(format: "%02dh %02dm", h, m)
    }
}

#Preview {
    ContentView()
        .environmentObject(TimerManager())
}
