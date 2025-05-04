// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "Mend",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(name: "Mend Health", targets: ["Mend Health"])
    ],
    dependencies: [
        .package(url: "https://github.com/stripe/stripe-ios-spm", from: "24.12.1")
    ],
    targets: [
        .target(
            name: "Mend Health",
            dependencies: [
                .product(name: "Stripe", package: "stripe-ios-spm"),
                .product(name: "StripeApplePay", package: "stripe-ios-spm"),
                .product(name: "StripePaymentSheet", package: "stripe-ios-spm")
            ],
            path: "Mend"
        )
    ]
) 