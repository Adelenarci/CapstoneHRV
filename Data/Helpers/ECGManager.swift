import Foundation
import HealthKit
import UIKit

/// Represents a single ECG data point with a unique identifier.
struct ECGDataPoint: Identifiable, Hashable {
    let id = UUID()  // 🔥 Ensures each point is unique
    let time: Double
    let voltage: Double
}

/// ECG Manager: Handles fetching, processing, and exporting ECG data.
@MainActor
class ECGManager: ObservableObject {
    let healthStore = HKHealthStore()
    
    @Published var ecgSamples: [MockECGSample] = []
    @Published var selectedECG: MockECGSample?
    @Published var ecgData: [ECGDataPoint] = []  // ✅ Uses a Hashable struct
    @Published var detectedPeaks: [Double] = []
    @Published var isLoading = false
    @Published var isSimulator = false

    /// Initializes the ECGManager and requests HealthKit authorization
    init() {
        requestAuthorization() // ✅ Ensure HealthKit permission is requested
        #if targetEnvironment(simulator)
        isSimulator = true
        #endif
    }

    /// Requests HealthKit authorization to access ECG data.
    func requestAuthorization() {
        let ecgType = HKObjectType.electrocardiogramType()
        
        healthStore.requestAuthorization(toShare: nil, read: [ecgType]) { success, error in
            DispatchQueue.main.async {
                if success {
                    print("✅ HealthKit access granted for ECG")
                } else {
                    print("❌ Error requesting HealthKit access: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        }
    }

    /// Fetch ECG samples from HealthKit or mock data for the simulator.
    func fetchECGSamples() {
        if isSimulator {
            DispatchQueue.main.async {
                self.ecgSamples = createMockECGSamples()
            }
            return
        }

        let ecgType = HKObjectType.electrocardiogramType()
        let query = HKSampleQuery(sampleType: ecgType, predicate: nil, limit: 10,
                                  sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)])
        { _, results, error in
            if let error = error {
                print("❌ Error fetching ECG samples: \(error.localizedDescription)")
                return
            }

            guard let ecgResults = results as? [HKElectrocardiogram], !ecgResults.isEmpty else {
                print("❌ No ECG samples found. Ensure you have recorded an ECG in Apple Health.")
                return
            }

            DispatchQueue.main.async {
                self.ecgSamples = ecgResults.map {
                    MockECGSample(
                        id: $0.uuid,
                        startDate: $0.startDate,
                        duration: $0.endDate.timeIntervalSince($0.startDate)
                    )
                }
                print("✅ Successfully fetched \(self.ecgSamples.count) ECG samples.")
            }
        }
        healthStore.execute(query)
    }

    /// Fetch ECG Data points and detect peaks.
    func fetchECGData() {
        guard let selectedECG = selectedECG else { return }

        isLoading = true

        DispatchQueue.global(qos: .userInitiated).async {
            DispatchQueue.main.async {
                // ✅ Clears previous ECG data before processing new data
                self.ecgData.removeAll()
                self.detectedPeaks.removeAll()
            }

            let rawData = createMockECGData()
            let peaks = detectPeaks(in: rawData)

            DispatchQueue.main.async {
                self.ecgData = rawData.map { ECGDataPoint(time: $0.time, voltage: $0.voltage) } // 🔥 Convert to struct
                self.detectedPeaks = peaks
                self.isLoading = false
                print("✅ Processed \(self.ecgData.count) ECG data points.")
            }
        }
    }

    /// Exports ECG data as a CSV file and allows sharing.
    func exportECGDataAsCSV() {
        guard !ecgData.isEmpty else {
            print("No ECG data available for export.")
            return
        }

        var csvString = "Time (s), Voltage (µV)\n"
        
        for entry in ecgData {
            csvString += "\(String(format: "%.6f", entry.time)), \(entry.voltage)\n" // ✅ Highly detailed timestamps
        }

        let fileName = "ECGData.csv"
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try csvString.write(to: path, atomically: true, encoding: .utf8)
            let activityVC = UIActivityViewController(activityItems: [path], applicationActivities: nil)
            
            if let topVC = UIApplication.shared.connectedScenes
                .compactMap({ ($0 as? UIWindowScene)?.windows.first?.rootViewController })
                .first {
                topVC.present(activityVC, animated: true, completion: nil)
            }
            print("✅ Successfully exported ECG data as CSV.")
        } catch {
            print("❌ Failed to save CSV: \(error.localizedDescription)")
        }
    }
}

