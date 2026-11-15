# Contributing to Mochi

Thanks for helping! Mochi is a small project, so the process is light.

## Setup

```bash
git clone <repo-url>
cd Mochi
swift build
swift run
```

You need macOS 13+ and a Swift 5.9+ toolchain.

## Making changes

1. Fork the repo and create a branch (`feature/my-idea`).
2. Keep changes focused: one feature or fix per pull request.
3. Make sure `swift build` succeeds with no new warnings.
4. If you changed how a pet looks, run `swift run Mochi --render preview.png` and attach the image to your PR.
5. Open a pull request describing what changed and why.

## Ideas that are easy to start with

- A new pet (`Pet/Model/Species.swift` + a drawing branch in `Pet/View/`)
- A new trick (`PetAction` in `Brain/Brain.swift`, handled in `PetController+Behavior.swift`)
- New lines for `Pet/Model/Dialogue.swift`

## Reporting bugs

Please include your macOS version, which pet you were using, and steps to reproduce. For
"the pet went somewhere weird" bugs, mention whether you use multiple monitors or a Dock on the side.
