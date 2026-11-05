// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LGRemote",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "LGRemote", targets: ["LGRemote"]),
    ],
    targets: [
        .target(name: "LGRemoteCore"),
        .executableTarget(name: "LGRemote", dependencies: ["LGRemoteCore"]),
        .testTarget(name: "LGRemoteCoreTests", dependencies: ["LGRemoteCore"]),
    ]
)
