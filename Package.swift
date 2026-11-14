// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Mochi",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Mochi",
            path: "Sources/Mochi",
            linkerSettings: [
                // Embed Info.plist in the binary, so `swift run` has the same identity (and saved data)
                // as the built Mochi.app, and macOS can show the calendar permission prompt.
                .unsafeFlags(["-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist",
                              "-Xlinker", "\(Context.packageDirectory)/Support/Info.plist"])
            ]
        )
    ]
)
