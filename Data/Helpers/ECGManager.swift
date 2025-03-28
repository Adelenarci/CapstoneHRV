import Foundation
import SwiftUI
import HealthKit
import UIKit

struct ECGDataPoint: Identifiable, Hashable {
    let id = UUID()
    let time: Double
    let voltage: Double
}

struct ECGSample: Identifiable, Codable {
    let id: UUID
    let startDate: Date
    let duration: TimeInterval
    var folderName: String?

    private enum CodingKeys: String, CodingKey {
        case id, startDate, duration, folderName
    }
}

@MainActor
class ECGManager: ObservableObject {
    let healthStore = HKHealthStore()

    @Published var ecgSamples: [ECGSample] = []
    @Published var ecgData: [ECGDataPoint] = []
    @Published var detectedPeaks: [Double] = []
    @Published var isLoading = false
    @Published var isSimulator = false
    @Published var folders: [String: [ECGSample]] = [:]

    @AppStorage("ECGFolders") private var storedFolders: Data?

    init() {
        requestAuthorization()
        loadFolders()

        #if targetEnvironment(simulator)
        isSimulator = true
        print("✅ Running in Simulator - Using Mock ECG Data")
        #endif
    }

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

    func fetchECGSamples() {
        if isSimulator {
            DispatchQueue.main.async {
                self.ecgSamples = createMockECGSamples()
                print("✅ Mock ECG Samples Loaded: \(self.ecgSamples.count)")
            }
            return
        }

        let ecgType = HKObjectType.electrocardiogramType()
        let query = HKSampleQuery(sampleType: ecgType, predicate: nil, limit: 10,
                                  sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) { _, results, error in
            if let error = error {
                print("❌ Error fetching ECG samples: \(error.localizedDescription)")
                return
            }

            guard let ecgResults = results as? [HKElectrocardiogram], !ecgResults.isEmpty else {
                print("❌ No ECG samples found.")
                return
            }

            DispatchQueue.main.async {
                self.ecgSamples = ecgResults.map {
                    ECGSample(
                        id: $0.uuid,
                        startDate: $0.startDate,
                        duration: $0.endDate.timeIntervalSince($0.startDate),
                        folderName: nil
                    )
                }
                self.loadFolders()
                print("✅ Successfully fetched \(self.ecgSamples.count) ECG samples.")
            }
        }
        healthStore.execute(query)
    }

    func fetchECGData(for sample: ECGSample) {
        isLoading = true
        ecgData.removeAll()
        detectedPeaks.removeAll()

        let predicate = HKQuery.predicateForObjects(with: [sample.id])

        let query = HKSampleQuery(sampleType: HKObjectType.electrocardiogramType(), predicate: predicate, limit: 1, sortDescriptors: nil) { _, results, error in
            guard let ecgSample = results?.first as? HKElectrocardiogram else {
                DispatchQueue.main.async {
                    print("❌ No ECG data found for sample: \(sample.id).")
                    self.isLoading = false
                }
                return
            }

            var fetchedData: [ECGDataPoint] = []

            let voltageQuery = HKElectrocardiogramQuery(ecgSample) { query, result in
                switch result {
                case .error(let error):
                    DispatchQueue.main.async {
                        print("❌ Error fetching ECG voltage data: \(error.localizedDescription)")
                        self.isLoading = false
                    }

                case .measurement(let measurement):
                    if let voltageQuantity = measurement.quantity(for: .appleWatchSimilarToLeadI) {
                        let voltageValue = voltageQuantity.doubleValue(for: HKUnit.volt())
                        let microvoltValue = voltageValue * 1_000_000
                        let timeValue = Double(fetchedData.count) / 512.0
                        fetchedData.append(ECGDataPoint(time: timeValue, voltage: microvoltValue))
                    }

                case .done:
                    DispatchQueue.main.async {
                        self.ecgData = fetchedData
                        self.detectedPeaks = detectPeaks(in: fetchedData.map { ($0.time, $0.voltage) })
                        self.isLoading = false
                        print("✅ Successfully fetched \(self.ecgData.count) ECG data points from HealthKit.")
                    }
                }
            }

            self.healthStore.execute(voltageQuery)
        }

        healthStore.execute(query)
    }

    func assignECGToFolder(_ sample: ECGSample, folder: String) {
        var updatedSample = sample
        updatedSample.folderName = folder

        if folders[folder] == nil {
            folders[folder] = []
        }
        folders[folder]?.append(updatedSample)

        saveFolders()
    }

    func removeECGFromFolder(_ sample: ECGSample) {
        if let folder = sample.folderName {
            folders[folder]?.removeAll { $0.id == sample.id }
            if folders[folder]?.isEmpty == true {
                folders.removeValue(forKey: folder)
            }
        }
        saveFolders()
    }

    func saveFolders() {
        if let encoded = try? JSONEncoder().encode(folders) {
            storedFolders = encoded
        }
    }

    private func loadFolders() {
        if let data = storedFolders, let savedFolders = try? JSONDecoder().decode([String: [ECGSample]].self, from: data) {
            folders = savedFolders
        }
    }

    func exportECGDataAsCSV(for sample: ECGSample) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard !self.ecgData.isEmpty else {
                print("❌ No ECG data available for export.")
                return
            }

            var csvString = "Time (s);Voltage (mV)\n"
            for entry in self.ecgData {
                let timeFormatted = String(format: "%.6f", entry.time)
                let voltageFormatted = String(format: "%.6f", entry.voltage / 1000.0) // µV → mV
                csvString += "\(timeFormatted);\(voltageFormatted)\n"
            }

            let fileName = "ECGData_\(formatDateForFile(sample.startDate))"
            let path = FileManager.default.temporaryDirectory.appendingPathComponent("\(fileName).csv")

            do {
                try csvString.write(to: path, atomically: true, encoding: .utf8)
                DispatchQueue.main.async {
                    let activityVC = UIActivityViewController(activityItems: [path], applicationActivities: nil)
                    if let topVC = UIApplication.shared.connectedScenes
                        .compactMap({ ($0 as? UIWindowScene)?.windows.first?.rootViewController })
                        .first {
                        topVC.present(activityVC, animated: true, completion: nil)
                    }
                    print("✅ Successfully exported ECG data as \(fileName).csv")
                }
            } catch {
                print("❌ Failed to save CSV: \(error.localizedDescription)")
            }
        }
    }

}

private func formatDateForFile(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
    return formatter.string(from: date)
}
