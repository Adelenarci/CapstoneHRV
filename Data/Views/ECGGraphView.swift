import SwiftUI
import Charts

struct ECGGraphView: View {
    let ecgData: [ECGDataPoint]
    let detectedPeaks: [Double]
    @AppStorage("themeColor") private var themeColor: String = "Blue"

    var selectedColor: Color {
        switch themeColor {
        case "Green": return .green
        case "Red": return .red
        case "Purple": return .purple
        default: return .blue
        }
    }

    /// Dynamically calculate min and max time for X-axis
    var timeRange: ClosedRange<Double> {
        guard let firstTime = ecgData.first?.time, let lastTime = ecgData.last?.time else {
            return 0...30 // Default range if no data
        }
        return firstTime...(lastTime + 1) // Add padding for better visualization
    }

    /// Dynamically calculate min and max voltage for Y-axis
    var voltageRange: ClosedRange<Double> {
        let voltages = ecgData.map { $0.voltage }
        guard let minVoltage = voltages.min(), let maxVoltage = voltages.max() else {
            return -100...100  // Default range if no data
        }
        return (minVoltage - 10)...(maxVoltage + 10) // Add padding for better visibility
    }

    var body: some View {
        if ecgData.isEmpty {
            Text("No ECG data available")
                .font(.headline)
                .foregroundColor(.gray)
                .frame(height: 250)
                .padding()
        } else {
            ScrollView(.horizontal) { // ✅ Allows horizontal scrolling
                VStack {
                    Text("")
                        .font(.headline)
                        .padding(.top, 5)

                    Chart {
                        ForEach(ecgData) { data in
                            LineMark(
                                x: .value("Time (s)", data.time),
                                y: .value("Voltage (µV)", data.voltage)
                            )
                            .foregroundStyle(selectedColor)
                            .interpolationMethod(.catmullRom)
                        }

                        ForEach(detectedPeaks, id: \.self) { peak in
                            PointMark(
                                x: .value("Peak Time", peak),
                                y: .value("Voltage", 100)
                            )
                            .foregroundStyle(.red)
                            .symbol(.circle)
                        }
                    }
                    .chartXScale(domain: timeRange) // ✅ Dynamically adjusts based on real data
                    .chartYScale(domain: voltageRange) // ✅ Auto-adjusts Y-axis based on data
                    .chartXAxis {
                        AxisMarks(position: .bottom) { value in
                            AxisGridLine()
                            AxisTick()
                            if let number = value.as(Double.self) {
                                AxisValueLabel(formatNumber(number) + " s") // ✅ Time in seconds
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine()
                            AxisTick()
                            if let number = value.as(Double.self) {
                                AxisValueLabel(formatNumber(number) + " µV") // ✅ Voltage in µV
                            }
                        }
                    }
                    .frame(width: max(CGFloat(ecgData.count) * 1.5, 900), height: 250) // ✅ Adjusts width based on data size
                    .padding()
                }
            }
            .frame(height: 270)
            .padding(.horizontal)
        }
    }

    /// Formats numbers to 1 decimal place (e.g., `2.3`)
    func formatNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
