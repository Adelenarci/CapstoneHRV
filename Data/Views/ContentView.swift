import SwiftUI

struct ContentView: View {
    @StateObject private var ecgManager = ECGManager()

    var body: some View {
        TabView {
            ECGDataView(ecgManager: ecgManager)
                .tabItem {
                    Image(systemName: "waveform.path.ecg")
                    Text("ECG Data")
                }

            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("Settings")
                }
        }
    }
}

