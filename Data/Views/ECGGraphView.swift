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

    /// Calculate min and max voltage for dynamic Y-axis adjustment
    var voltageRange: ClosedRange<Double> {
        let voltages = ecgData.map { $0.voltage }
        guard let minVoltage = voltages.min(), let maxVoltage = voltages.max() else {
            return -100...100  // Default range if no data
        }
        return (minVoltage - 10)...(maxVoltage + 10) // Add padding for better visibility
    }

    var body: some View {
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
                .chartXScale(domain: 0...30) // ✅ Ensures 30-second display range
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
                .frame(width: 900, height: 250) // ✅ Large width ensures scrollability
                .padding()
            }
        }
        .frame(height: 270)
        .padding(.horizontal)
    }
    
    /// Formats numbers to 1 decimal place (e.g., `2.3`)
    func formatNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

