# YoungMetro

The typical metronome click was too harsh on my ears so I wanted one with a gentler sound. Here is a simple iOS metronome with a kickdrum sound, made for keeping a steady turnover rate while running. Default bpm 175, and you can custom upload whatever metronome sound you want.

## Features

- Sample-accurate timing via `AVAudioEngine` (no timer drift)
- Upload custom beat sounds (WAV, MP3, M4A, AIFF, etc.)
- Background audio — keeps ticking when the screen is locked
- BPM range: 40–240

## Requirements

- macOS with **Xcode 15+**
- iPhone running iOS 17+ (or use the Simulator for basic testing)

## Getting Started

1. Open `Metronome.xcodeproj` in Xcode
2. Select your **Development Team** under Signing & Capabilities (Target → Metronome → Signing)
3. Connect your iPhone and select it as the run destination
4. Press **Run** (⌘R)

### Free Apple ID

A free Apple ID works for personal device installs. The app will expire after ~7 days and needs to be re-deployed from Xcode.

## Project Structure

```
Metronome/
├── MetronomeApp.swift       App entry point
├── MetronomeEngine.swift    Audio engine + beat scheduler
├── BeatSoundStore.swift     Custom sound import & PCM buffer loading
├── ContentView.swift        UI (BPM slider, play/stop, upload)
├── DocumentPicker.swift     File picker wrapper
├── Info.plist               Background audio mode
└── Resources/
    └── default_click.wav    Bundled fallback click
```

## Testing on Device

After deploying, verify:

1. **Timing** — set 120 BPM, listen for steady clicks for a few seconds
2. **Custom sound** — tap Upload Sound, pick a short audio file (< 100 ms ideal)
3. **Background** — start the metronome, lock the screen, confirm clicks continue
4. **BPM change** — adjust the slider while playing; timing should re-sync within one beat
