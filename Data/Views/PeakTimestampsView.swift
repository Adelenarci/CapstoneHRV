import SwiftUI

struct PeakTimestampsView: View {
    let detectedPeaks: [Double]

    var body: some View {
        VStack {
            Text("Detected Peaks (Time in sec)")
                .font(.headline)
                .padding(.top, 10)
            ScrollView(.horizontal) {
                HStack {
                    ForEach(detectedPeaks, id: \.self) { peak in
                        Text("\(peak, specifier: "%.3f")s")
                            .padding(5)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(5)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}
