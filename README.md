# singedR

Here is a simple iOS metronome with a kickdrum sound, made for keeping a steady turnover rate while running. (The usual metronome click was too harsh for me, so I wanted one with a gentler sound.) Default bpm 175, and you can custom upload whatever metronome sound you want.

## Notes

Singed's ultimate ability gives him many stat boosts and arguably the most notable one is that he becomes faster. Hope that locking into 175 steps per minute can help you do the same!

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

## Testing on Device

After deploying, verify:

1. **Timing** — set 175 BPM, listen for steady clicks for a few seconds
2. **Custom sound** — tap Upload Sound, pick a short audio file (< 100 ms ideal)
3. **Background** — start the metronome, lock the screen, confirm clicks continue
4. **BPM change** — adjust the slider while playing; timing should re-sync within one beat
