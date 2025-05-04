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
        .package(url: "https://github.com/stripe/stripe-ios", from: "23.18.0")
    ],
    targets: [
        .target(
            name: "Mend Health",
            dependencies: [
                .product(name: "Stripe", package: "stripe-ios"),
                .product(name: "StripeApplePay", package: "stripe-ios"),
                .product(name: "StripePaymentSheet", package: "stripe-ios")
            ],
            path: "Mend"
        )
    ]
) 