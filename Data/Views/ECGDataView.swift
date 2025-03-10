import SwiftUI

struct ECGDataView: View {
    @ObservedObject var ecgManager = ECGManager()
    @AppStorage("themeColor") private var themeColor: String = "Blue"
    @State private var graphID = UUID() // ✅ Ensures UI refresh when ECG is processed

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 15) {
                    Text("ECG Data Exporter")
                        .font(.title2)
                        .bold()
                        .padding(.top, 5)

                    Button(action: ecgManager.fetchECGSamples) {
                        Label("Fetch ECG Samples", systemImage: "waveform.path.ecg")
                    }
                    .primaryButtonStyle()

                    // ✅ ECG List
                    ECGListView(ecgSamples: ecgManager.ecgSamples, selectedECG: $ecgManager.selectedECG)
                        .padding(.bottom, 10)

                    // ✅ Graph Section (Only one!)
                    if !ecgManager.ecgData.isEmpty {
                        VStack {
                            Text("ECG Waveform") // ✅ Text is only shown once
                                .font(.headline)
                                .padding(.top, 10)

                            ECGGraphView(ecgData: ecgManager.ecgData, detectedPeaks: ecgManager.detectedPeaks)
                                .id(graphID) // ✅ Refreshes when processing ECG
                                .frame(height: 250)
                                .padding(.horizontal)
                        }
                        .background(RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.systemBackground))
                                        .shadow(radius: 2))
                        .padding(.bottom, 10)
                    }

                    if !ecgManager.detectedPeaks.isEmpty {
                        PeakTimestampsView(detectedPeaks: ecgManager.detectedPeaks)
                    }

                    Button(action: {
                        ecgManager.fetchECGData()
                        graphID = UUID() // ✅ Refresh UI when processing ECG
                    }) {
                        Label("Process Selected ECG", systemImage: "play.circle.fill")
                    }
                    .primaryButtonStyle(disabled: ecgManager.selectedECG == nil)
                    .disabled(ecgManager.selectedECG == nil)

                    if ecgManager.isLoading {
                        ProgressView("Processing ECG Data...")
                            .padding()
                    }
                    Button(action: {
                        ecgManager.exportECGDataAsCSV() // ✅ Directly calling the function
                    }) {
                        Label("Export as CSV", systemImage: "square.and.arrow.up")
                    }
                    .primaryButtonStyle(disabled: ecgManager.ecgData.isEmpty)
                    .disabled(ecgManager.ecgData.isEmpty)



                    Spacer()
                }
                .padding()
            }
        }
    }
}

