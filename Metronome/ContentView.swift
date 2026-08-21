import SwiftUI

struct ContentView: View {
    @StateObject private var engine = MetronomeEngine()
    @State private var showDocumentPicker = false
    @State private var importError: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                bpmSection
                playButton
                soundSection
            }
            .padding()
            .navigationTitle("YoungMetro")
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPicker { url in
                    showDocumentPicker = false
                    Task {
                        do {
                            try await engine.importSound(from: url)
                        } catch {
                            importError = error.localizedDescription
                        }
                    }
                }
            }
            .alert("Import Failed", isPresented: .init(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            )) {
                Button("OK") { importError = nil }
            } message: {
                Text(importError ?? "")
            }
        }
    }

    private var bpmSection: some View {
        VStack(spacing: 12) {
            Text("\(Int(engine.bpm))")
                .font(.system(size: 72, weight: .thin, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())

            Text("BPM")
                .font(.title3)
                .foregroundStyle(.secondary)

            Slider(
                value: $engine.bpm,
                in: MetronomeEngine.minBPM...MetronomeEngine.maxBPM,
                step: 1
            )
            .padding(.horizontal)
        }
    }

    private var playButton: some View {
        Button(action: engine.toggle) {
            Image(systemName: engine.isPlaying ? "stop.fill" : "play.fill")
                .font(.system(size: 36))
                .foregroundStyle(.white)
                .frame(width: 88, height: 88)
                .background(engine.isPlaying ? Color.red : Color.accentColor)
                .clipShape(Circle())
        }
        .animation(.easeInOut(duration: 0.2), value: engine.isPlaying)
    }

    private var soundSection: some View {
        VStack(spacing: 12) {
            if let name = engine.customSoundName {
                Label(name, systemImage: "waveform")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else {
                Label("Default click", systemImage: "waveform")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                Button("Upload Sound") {
                    showDocumentPicker = true
                }
                .buttonStyle(.bordered)

                if engine.customSoundName != nil {
                    Button("Reset") {
                        try? engine.resetToDefaultSound()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
