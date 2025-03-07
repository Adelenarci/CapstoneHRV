import SwiftUI
import HealthKit

@main
struct DataApp: App {  // ✅ Use "DataApp" instead of "ECGExporterApp"
    let healthStore = HKHealthStore()

    init() {
        requestHealthKitPermissions()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    func requestHealthKitPermissions() {
        let ecgType = HKObjectType.electrocardiogramType()
        healthStore.requestAuthorization(toShare: nil, read: [ecgType]) { success, error in
            if success {
                print("HealthKit access granted for ECG")
            } else {
                print("Error requesting HealthKit access: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
}

