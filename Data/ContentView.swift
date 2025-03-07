import SwiftUI
import HealthKit

struct ContentView: View {
    let healthStore = HKHealthStore()
    @State private var ecgSamples: [MockECGSample] = []
    @State private var selectedECG: MockECGSample?
    @State private var ecgData: [(time: String, voltage: Double)] = []
    @State private var csvText: String = "Time,Voltage (µV)\n"
    @State private var isSimulator = false
    @State private var isLoading = false

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [.blue.opacity(0.2), .white]), startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            
            VStack(spacing: 15) {
                Text("ECG Data Exporter")
                    .font(.largeTitle)
                    .bold()
                    .padding(.top, 20)

                Button(action: fetchECGSamples) {
                    HStack {
                        Image(systemName: "waveform.path.ecg")
                        Text("Fetch ECG Samples")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal)

                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(ecgSamples, id: \.id) { sample in
                            Button(action: {
                                selectedECG = sample
                            }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("ECG Recorded: \(formatDate(sample.startDate))")
                                            .font(.headline)
                                        Text("Duration: \(sample.duration, specifier: "%.1f") sec")
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Image(systemName: selectedECG == sample ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selectedECG == sample ? .green : .gray)
                                }
                                .padding()
                                .background(RoundedRectangle(cornerRadius: 10)
                                                .fill(selectedECG == sample ? Color.blue.opacity(0.2) : Color.white)
                                                .shadow(radius: 2))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(maxHeight: 300)

                Button(action: {
                    if let selectedECG = selectedECG {
                        fetchECGData(sample: selectedECG)
                    }
                }) {
                    HStack {
                        Image(systemName: "play.circle.fill")
                        Text("Process Selected ECG")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(selectedECG == nil ? Color.gray : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                .disabled(selectedECG == nil)

                Button(action: saveCSV) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export as CSV")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(ecgData.isEmpty ? Color.gray : Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                .disabled(ecgData.isEmpty)

                if isLoading {
                    ProgressView("Processing ECG Data...")
                        .padding()
                }
            }
            .padding()
        }
        .onAppear {
            #if targetEnvironment(simulator)
            isSimulator = true
            #endif
        }
    }

    func fetchECGSamples() {
        if isSimulator {
            DispatchQueue.main.async {
                self.ecgSamples = createMockECGSamples()
            }
            return
        }

        let ecgType = HKObjectType.electrocardiogramType()
        let query = HKSampleQuery(sampleType: ecgType, predicate: nil, limit: 10, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) { _, results, error in
            guard let ecgResults = results as? [HKElectrocardiogram] else {
                print("No ECG samples found.")
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
            }
        }
        healthStore.execute(query)
    }

    func fetchECGData(sample: MockECGSample) {
        isLoading = true

        if isSimulator {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.ecgData = self.createMockECGData()
                self.generateCSV()
                self.isLoading = false
            }
            return
        }

        print("Cannot fetch real ECG data in Simulator. Please use a real device.")
        isLoading = false
    }

    func generateCSV() {
        csvText = "Time,Voltage (µV)\n"
        for entry in ecgData {
            csvText += "\(entry.time),\(entry.voltage)\n"
        }
    }

    func saveCSV() {
        let fileName = "ECGData.csv"
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try csvText.write(to: path, atomically: true, encoding: .utf8)
            let activityVC = UIActivityViewController(activityItems: [path], applicationActivities: nil)
            if let topVC = UIApplication.shared.windows.first?.rootViewController {
                topVC.present(activityVC, animated: true, completion: nil)
            }
        } catch {
            print("Failed to save CSV: \(error.localizedDescription)")
        }
    }

    struct MockECGSample: Identifiable, Equatable {
        let id: UUID
        let startDate: Date
        let duration: TimeInterval

        static func == (lhs: MockECGSample, rhs: MockECGSample) -> Bool {
            return lhs.id == rhs.id
        }
    }

    func createMockECGSamples() -> [MockECGSample] {
        return [
            MockECGSample(id: UUID(), startDate: Date().addingTimeInterval(-3600), duration: 30.0),
            MockECGSample(id: UUID(), startDate: Date().addingTimeInterval(-7200), duration: 25.0)
        ]
    }

    func createMockECGData() -> [(time: String, voltage: Double)] {
        var mockData: [(String, Double)] = []
        for i in 0..<100 {
            let time = String(format: "%.6f", Double(i) * 0.002)
            let voltage = sin(Double(i) * 0.1) * 100
            mockData.append((time, voltage))
        }
        return mockData
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

