import UIKit
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        application.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
        return true
    }

    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // Trigger battery data capture and Firestore sync
        let batteryInfo = BatteryInfo()
        batteryInfo.captureCurrentBatteryLevel()
        batteryInfo.sendBatteryDataToFirestore()

        // Call completion handler
        completionHandler(.newData)
    }
}
