// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Groupdock",
    platforms: [.macOS(.v14)],
    products: [
        // A droplet is a loadable bundle, so its product is a dynamic library.
        // Do not make it static: the app already carries DroppyKit, and a
        // second copy inside the droplet gives the same type two metadata
        // records, which fails every cast between them.
        .library(name: "Groupdock", type: .dynamic, targets: ["Groupdock"])
    ],
    dependencies: [
        .package(url: "https://gitlab.com/droppyformac1/droppykit.git", from: "1.22.0")
    ],
    targets: [
        .target(
            name: "Groupdock",
            dependencies: [.product(name: "DroppyKit", package: "droppykit")]
        ),
        .executableTarget(
            name: "GroupdockShots",
            dependencies: ["Groupdock"]
        ),
        .executableTarget(
            name: "GroupdockHarness",
            dependencies: [
                "Groupdock",
                .product(name: "DroppyKitHarness", package: "droppykit")
            ]
        )
    ]
)
