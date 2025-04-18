import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @StateObject private var healthImporter = HealthDataImporter()
    @EnvironmentObject private var recoveryMetrics: RecoveryMetrics
    @State private var showingFilePicker = false
    @State private var showingError = false
    @State private var isImporting = false
    
    var body: some View {
        Form {
            Section(header: Text("Data Import")) {
                Button(action: {
                    showingFilePicker = true
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                            .foregroundColor(.accentColor)
                        Text("Import Apple Health Data")
                    }
                }
                .disabled(isImporting)
                
                if isImporting {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Importing data...")
                            .foregroundColor(.secondary)
                    }
                }
                
                Button(action: {
                    Task {
                        await recoveryMetrics.refreshData()
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.accentColor)
                        Text("Refresh Health Data")
                    }
                }
            }
            
            #if DEBUG
            Section(header: Text("Developer Options")) {
                Toggle("Use Simulated Data", isOn: $recoveryMetrics.useSimulatedData)
                    .onChange(of: recoveryMetrics.useSimulatedData) {
                        Task {
                            await recoveryMetrics.loadMetrics()
                        }
                    }
            }
            #endif
            
            Section(header: Text("About"), footer: Text("Imported health data is processed locally on your device.")) {
                Text("Version 1.0.0")
                    .foregroundColor(.secondary)
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [UTType.xml],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                
                // Start import process
                isImporting = true
                
                Task {
                    do {
                        let activities = try await healthImporter.importHealthData(from: url)
                        await MainActor.run {
                            // Here you would update your app's data store with the new activities
                            print("Successfully imported \(activities.count) activities")
                            isImporting = false
                        }
                    } catch {
                        await MainActor.run {
                            isImporting = false
                            showingError = true
                        }
                    }
                }
                
            case .failure(let error):
                print("Error selecting file: \(error.localizedDescription)")
                showingError = true
            }
        }
        .alert("Import Error",
               isPresented: $showingError,
               actions: {
            Button("OK", role: .cancel) { }
        }, message: {
            Text(healthImporter.error?.description ?? "Failed to import health data")
        })
        .navigationTitle("Settings")
    }
}

#Preview {
    NavigationView {
        SettingsView()
    }
} 