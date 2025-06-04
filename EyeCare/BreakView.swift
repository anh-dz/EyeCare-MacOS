import SwiftUI

struct BreakView: View {
    @Binding var isBreakTime: Bool
    @EnvironmentObject var timerManager: TimerManager
    @State private var windowController: BreakWindowController?

    var body: some View {
        EmptyView()
            .onAppear {
                if windowController == nil {
                    let controller = BreakWindowController(timerManager: timerManager)
                    controller.onClose = {
                        isBreakTime = false
                        timerManager.setBreakTime(false)
                        timerManager.setTimeRemaining(timerManager.workDuration)
                        timerManager.setBreakShouldShowEnd(false)
                        if timerManager.isRunning {
                            timerManager.startUsageTracking()
                            let _ = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { _ in
                                timerManager.toggleTimer() // stop
                                timerManager.toggleTimer() // start
                            }
                        }
                    }
                    windowController = controller
                }
                windowController?.show()
            }
            .onDisappear {
                windowController?.hide()
            }
    }
} 