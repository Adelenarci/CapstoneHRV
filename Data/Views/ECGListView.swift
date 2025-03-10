import SwiftUI

struct ECGListView: View {
    let ecgSamples: [MockECGSample]
    @Binding var selectedECG: MockECGSample?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Select an ECG Sample")
                .font(.headline)
                .padding(.leading, 15)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(ecgSamples, id: \.id) { sample in
                        sampleRow(sample)
                    }
                }
                .padding(.horizontal)
            }
            .frame(maxHeight: 250)
        }
        .padding(.horizontal)
    }

    private func sampleRow(_ sample: MockECGSample) -> some View {
        Button(action: {
            selectedECG = sample
        }) {
            HStack {
                VStack(alignment: .leading) {
                    Text("📅 \(formatDate(sample.startDate))")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("⏳ Duration: \(sample.duration, specifier: "%.1f") sec")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if selectedECG == sample {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(selectedECG == sample ? Color.blue.opacity(0.2) : Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

