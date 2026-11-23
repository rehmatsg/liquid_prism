// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "liquid_prism",
    platforms: [
        .iOS("15.0")
    ],
    targets: [
        .target(
            name: "liquid_prism",
            path: "ios/liquid_prism/Sources/liquid_prism",
            sources: [
                "LiquidMenu.swift",
                "MenuAnchorControl.swift",
                "MenuBuilder.swift",
                "MenuModels.swift",
                "MenuOverlayHost.swift",
                "MenuPresenter.swift",
                "SystemChromeObserver.swift",
                "DeviceGlass.swift",
                "SensorHousing.swift",
                "GlassDisplayObserver.swift"
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        ),
        .testTarget(
            name: "LiquidMenuTests",
            dependencies: ["liquid_prism"],
            path: "ios/liquid_prism/Tests/LiquidMenuTests"
        )
    ]
)
