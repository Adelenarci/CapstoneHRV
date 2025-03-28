import SwiftUI

struct HRVAnalysisView: View {
    let selectedECG: ECGSample
    @ObservedObject var ecgManager: ECGManager

    @State private var hrvData: [ECGDataPoint] = []
    @State private var detectedPeaks: [Double] = []
    @State private var hrvParameters: [String: Double] = [:]
    @State private var rrIntervals: [RRInterval] = []
    @State private var graphID = UUID()
    @State private var isAnalyzing = false

    struct RRInterval: Decodable, Identifiable {
        let id = UUID()
        let timestamp: Double
        let rr: Double?
    }

    struct HRVAnalysisResponse: Decodable {
        let hrvMetrics: [String: Double]
        let rrTable: [RRInterval]
    }

    var body: some View {
        NavigationView {
            VStack {
                Text("HRV Analysis")
                    .font(.largeTitle)
                    .padding()

                if isAnalyzing {
                    ProgressView("Analyzing ECG...")
                        .padding()
                } else if !hrvData.isEmpty {
                    ECGGraphView(ecgData: hrvData, detectedPeaks: detectedPeaks)
                        .id(graphID)
                        .frame(height: 300)
                        .padding()
                }

                if !rrIntervals.isEmpty {
                    List(rrIntervals) { interval in
                        HStack {
                            Text("\(interval.timestamp, specifier: "%.4f") s")
                            Spacer()
                            Text(interval.rr != nil ? "\(interval.rr!, specifier: "%.4f") s" : "—")
                        }
                    }
                    .frame(height: 200)
                }

                VStack(alignment: .leading) {
                    Text("HRV Parameters")
                        .font(.headline)
                        .padding(.bottom, 5)

                    ForEach(hrvParameters.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        HStack {
                            Text("\(key):")
                            Spacer()
                            Text("\(value, specifier: "%.2f")")
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .padding()

                Spacer()
            }
            .onAppear {
                loadAndAnalyzeECG()
            }
        }
    }

    private func loadAndAnalyzeECG() {
        isAnalyzing = true
        ecgManager.fetchECGData(for: selectedECG)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            guard !ecgManager.ecgData.isEmpty else {
                isAnalyzing = false
                print("❌ No ECG data found.")
                return
            }

            hrvData = ecgManager.ecgData
            detectedPeaks = detectPeaks(in: ecgManager.ecgData.map { ($0.time, $0.voltage) })
            graphID = UUID()

            sendECGToBackend(ecgData: hrvData)
        }
    }

    private func sendECGToBackend(ecgData: [ECGDataPoint]) {
        // ✅ Prepare CSV as: Time (s);Voltage (mV)
        var csvString = "Time (s);Voltage (mV)\n"
        ecgData.forEach { point in
            let voltageInMV = point.voltage / 1000.0
            csvString += "\(String(format: "%.6f", point.time));\(String(format: "%.3f", voltageInMV))\n"
        }

        guard let csvData = csvString.data(using: .utf8) else {
            print("❌ CSV encoding failed.")
            isAnalyzing = false
            return
        }

        // ✅ Create multipart/form-data request
        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: "https://capstoneapi-85nh.onrender.com/analyze")!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"ecg.csv\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: text/csv\r\n\r\n".data(using: .utf8)!)
        body.append(csvData)
        body.append("\r\n".data(using: .utf8)!)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"start_index\"\r\n\r\n".data(using: .utf8)!)
        body.append("0\r\n".data(using: .utf8)!)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        // ✅ Call the API
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isAnalyzing = false
            }

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("❌ API Error: \(error?.localizedDescription ?? "Unknown error")")
                return
            }

            if let metricsHeader = httpResponse.allHeaderFields["X-Metrics"] as? String,
               let metricsData = metricsHeader.data(using: .utf8),
               let decoded = try? JSONDecoder().decode(HRVAnalysisResponse.self, from: metricsData) {

                DispatchQueue.main.async {
                    self.hrvParameters = decoded.hrvMetrics
                    self.rrIntervals = decoded.rrTable
                    print("✅ HRV data received and parsed.")
                }
            } else {
                print("❌ Failed to decode X-Metrics header.")
            }
        }.resume()
    }
}
