import Foundation

public struct AppConfiguration: Codable {
    let features: Features
    let identifiers: Identifiers
    let limits: Limits
    let timing: Timing
}

public struct Features: Codable {
    let openAd: String
    let openAdOnSplash: String
    let banner: String
    let fullScreen: String
    let native: String
    let nativePreload: String

    var isOpenAdEnabled: Bool {
        openAd == "Y"
    }

    var isOpenAdOnSplashEnabled: Bool {
        openAdOnSplash == "Y"
    }

    var isBannerEnabled: Bool {
        banner == "Y"
    }

    var isFullScreenEnabled: Bool {
        fullScreen == "Y"
    }

    var isNativeEnabled: Bool {
        native == "Y"
    }

    var isNativePreloadEnabled: Bool {
        nativePreload == "Y"
    }
}

public struct Identifiers: Codable {
    let openAd: String
    let banner: String
    let fullScreen: String
    let native: String
}

public struct Limits: Codable {
    let frequency: Int
    let session: Int
    let nativePreloadCount: Int
    let bannerErrors: Int
    let fullScreenErrors: Int
    let nativeErrors: Int
}

public struct Timing: Codable {
    let splashDelaySeconds: TimeInterval
}
