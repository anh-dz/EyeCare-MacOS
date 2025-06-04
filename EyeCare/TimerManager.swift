import Foundation
import SwiftUI
import UserNotifications

class TimerManager: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var isBreakTime = false
    @Published private(set) var isRunning = false
    @Published private(set) var timeRemaining: Int
    @Published private(set) var workDuration: Int // in seconds
    @Published private(set) var breakDuration: Int // in seconds
    @Published private(set) var showBreakWarning = false
    @Published private(set) var breakShouldShowEnd: Bool = false
    
    // MARK: - Private Properties
    private var workTimer: Timer?
    private var breakTimer: Timer?
    private var countdownTimer: Timer?
    private var usageTimer: Timer?
    private let usageKeyPrefix = "EyeCareUsage_"
    private let workDurationKey = "EyeCareWorkDuration"
    private let breakDurationKey = "EyeCareBreakDuration"
    private let usageDictKey = "EyeCareUsageDict"
    private let updateInterval: TimeInterval = 1.0
    private var lastUsageUpdate: Date = Date()
    private let minimumUsageUpdateInterval: TimeInterval = 1.0
    
    // MARK: - Initialization
    init() {
        let defaultWork = 20 * 60
        let defaultBreak = 20
        // Load from UserDefaults or use defaults
        let savedWork = UserDefaults.standard.integer(forKey: workDurationKey)
        let savedBreak = UserDefaults.standard.integer(forKey: breakDurationKey)
        let initialWork = savedWork > 0 ? savedWork : defaultWork
        let initialBreak = savedBreak > 0 ? savedBreak : defaultBreak
        self.workDuration = initialWork
        self.breakDuration = initialBreak
        self.timeRemaining = initialWork
        cleanOldUsageData()
        setupNotifications()
    }
    
    private func setupNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Error requesting notification authorization: \(error)")
            }
        }
    }
    
    // MARK: - Public Methods
    func toggleTimer() {
        if isRunning {
            stopTimer()
        } else {
            startTimer()
        }
    }
    
    func setBreakTime(_ value: Bool) {
        isBreakTime = value
    }
    
    func setBreakShouldShowEnd(_ value: Bool) {
        breakShouldShowEnd = value
    }
    
    func setShowBreakWarning(_ value: Bool) {
        showBreakWarning = value
    }
    
    func setTimeRemaining(_ value: Int) {
        timeRemaining = value
    }
    
    func setWorkDuration(minutes: Int) {
        let newDuration = minutes * 60
        guard newDuration != workDuration else { return }
        
        workDuration = newDuration
        if !isBreakTime && isRunning {
            let timeElapsed = workDuration - timeRemaining
            timeRemaining = newDuration - timeElapsed
            startWorkTimer()
        } else if !isBreakTime {
            timeRemaining = newDuration
        }
        saveSettings()
    }
    
    func setBreakDuration(seconds: Int) {
        guard seconds != breakDuration else { return }
        
        breakDuration = seconds
        if isBreakTime && isRunning {
            let timeElapsed = breakDuration - timeRemaining
            timeRemaining = seconds - timeElapsed
            startBreak(after: 0.5)
        } else if isBreakTime {
            timeRemaining = seconds
        }
        saveSettings()
    }
    
    func startBreak(after delay: TimeInterval = 0) {
        breakShouldShowEnd = false
        isRunning = true
        isBreakTime = true
        timeRemaining = breakDuration
        breakTimer?.invalidate()
        countdownTimer?.invalidate()
        startBreakTimerAndCountdown()
        stopUsageTracking()
    }
    
    func skipToBreak() {
        isRunning = true
        workTimer?.invalidate()
        countdownTimer?.invalidate()
        showBreakWarning = false
        startBreak()
    }
    
    func startUsageTracking() {
        usageTimer?.invalidate()
        lastUsageUpdate = Date()
        usageTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.incrementUsage()
        }
        usageTimer?.tolerance = 0.1
    }
    
    func stopUsageTracking() {
        usageTimer?.invalidate()
        usageTimer = nil
    }
    
    func resetAllUsageData() {
        UserDefaults.standard.removeObject(forKey: usageDictKey)
        objectWillChange.send()
    }
    
    // MARK: - Private Methods
    private func startTimer() {
        isRunning = true
        if !isBreakTime {
            startWorkTimer()
            startCountdownTimer()
            startUsageTracking()
        } else {
            startBreak(after: 0.5)
        }
    }
    
    private func stopTimer() {
        isRunning = false
        workTimer?.invalidate()
        breakTimer?.invalidate()
        countdownTimer?.invalidate()
        isBreakTime = false
        timeRemaining = workDuration
        stopUsageTracking()
    }
    
    private func startWorkTimer() {
        workTimer?.invalidate()
        workTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(workDuration - 15), repeats: false) { [weak self] _ in
            self?.scheduleBreakWarning()
        }
        workTimer?.tolerance = 0.1
    }
    
    private func scheduleBreakWarning() {
        let content = UNMutableNotificationContent()
        content.title = "Break Time Coming!"
        content.body = "Your break will start in 15 seconds"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "breakWarning", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            self?.startBreak(after: 0.5)
        }
    }
    
    private func startCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            if self.timeRemaining > 0 && self.isRunning && !self.isBreakTime {
                self.timeRemaining -= 1
            } else {
                timer.invalidate()
            }
        }
        countdownTimer?.tolerance = 0.1
    }
    
    private func startBreakCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            if self.timeRemaining > 0 && self.isRunning && self.isBreakTime {
                self.timeRemaining -= 1
            } else {
                timer.invalidate()
                self.breakShouldShowEnd = true
            }
        }
        countdownTimer?.tolerance = 0.1
    }
    
    private func startBreakTimerAndCountdown() {
        startBreakCountdownTimer()
    }
    
    private func incrementUsage() {
        guard !isBreakTime, isRunning else { return }
        
        let now = Date()
        guard now.timeIntervalSince(lastUsageUpdate) >= minimumUsageUpdateInterval else { return }
        
        lastUsageUpdate = now
        let todayKey = dateString(now)
        var usageDict = UserDefaults.standard.dictionary(forKey: usageDictKey) as? [String: Double] ?? [:]
        let current = usageDict[todayKey] ?? 0
        usageDict[todayKey] = current + minimumUsageUpdateInterval
        UserDefaults.standard.set(usageDict, forKey: usageDictKey)
    }
    
    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private func cleanOldUsageData() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: today)!
        
        var usageDict = UserDefaults.standard.dictionary(forKey: usageDictKey) as? [String: Double] ?? [:]
        usageDict = usageDict.filter { key, _ in
            if let date = dateFormatter.date(from: key) {
                return date >= weekAgo
            }
            return false
        }
        UserDefaults.standard.set(usageDict, forKey: usageDictKey)
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    func saveSettings() {
        UserDefaults.standard.set(workDuration, forKey: workDurationKey)
        UserDefaults.standard.set(breakDuration, forKey: breakDurationKey)
    }
    
    func loadSettings() {
        let savedWork = UserDefaults.standard.integer(forKey: workDurationKey)
        if savedWork > 0 { workDuration = savedWork }
    }
    
    func getUsageForCurrentWeek() -> [(date: Date, seconds: TimeInterval)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Get the weekday (1 = Sunday, 2 = Monday, ..., 7 = Saturday)
        let weekday = calendar.component(.weekday, from: today)
        // Calculate days from Monday (2) to get to the start of the week
        let daysFromMonday = (weekday + 5) % 7
        
        // Get Monday of the current week
        guard let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: today) else {
            return []
        }
        
        let usageDict = UserDefaults.standard.dictionary(forKey: usageDictKey) as? [String: Double] ?? [:]
        
        // Generate array from Monday to Sunday
        return (0..<7).compactMap { dayOffset in
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: monday) else { return nil }
            let key = dateString(date)
            let seconds = usageDict[key] ?? 0
            return (date: date, seconds: seconds)
        }
    }
} 
 