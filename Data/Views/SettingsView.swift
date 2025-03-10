import SwiftUI

struct SettingsView: View {
    @AppStorage("themeColor") private var themeColor: String = "Blue"
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false

    let colors: [String] = ["Blue", "Green", "Red", "Purple"]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Appearance")) {
                    Picker("ECG Graph Color", selection: $themeColor) {
                        ForEach(colors, id: \.self) { color in
                            Text(color)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())

                    Toggle("Dark Mode", isOn: $isDarkMode)
                        .onChange(of: isDarkMode) { _ in
                            updateAppearance()
                        }
                }

                Section(header: Text("App Info")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.gray)
                    }

                    HStack {
                        Text("Developer")
                        Spacer()
                        Text("Your Name")
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }

    func updateAppearance() {
        UIApplication.shared.windows.first?.overrideUserInterfaceStyle = isDarkMode ? .dark : .light
    }
}
