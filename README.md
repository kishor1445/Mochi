# Mochi

A tiny desktop pet for macOS. Pick one of three pets; it wanders your screen, says hi,
climbs the screen edges, hangs from the top, and leaps onto your windows. No AI yet,
but the "brain" is a swappable interface so an LLM can be plugged in later.

## Pets
- **Mochi** the squishy blob
- **Miso** the curious cat
- **Clover** the bouncy bunny

## Run
```bash
swift run
```
Use the menu bar icon (or right-click the pet) for **Choose pet & settings...**, Say hi, Come here, Sleep and Quit.

## Things it does
- Walks along the Dock, climbs the left/right edges, crawls along the top, and comes back down
- Stands on top of your windows (follows them if you move them) and leaps up to them
- Drag it and let go near an edge: it clings there. Let go mid-screen: it falls onto a window or the Dock
- Eyes follow your cursor, it sometimes chases it, and it looks at you when you are near
- Click to pet it (hearts), click fast to make it blush, poke it while asleep
- Says hi at random (Silent / Quiet / Normal / Chatty), with time-of-day greetings
- Sleeps when ignored for a few minutes or late at night

## Layout (Sources/Mochi)
- `Brain.swift`: `PetAction`, `Brain` protocol, `RuleBrain` (swap in an AI brain here later)
- `PetController.swift`: window, 30fps loop, surfaces (floor / walls / ceiling / windows), physics
- `PetView.swift`: drawing for every pet and mood, mouse input
- `Species.swift`: pet definitions (colors, speed, lines). Add a new pet here + a drawing branch
- `Dialogue.swift`: everything it says
- `SpeechBubble.swift`: the bubble window
- `Platform.swift`: finds window tops to stand on (no permissions needed)
- `PetSettings.swift` / `SettingsView.swift`: saved preferences and the settings panel
- `Render.swift`: `Mochi --render out.png` writes a contact sheet for checking drawings
