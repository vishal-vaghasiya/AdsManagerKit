# AdsManagerKit

[TOC]

## **📚 Table of Contents**
- [✨ Features](#-features)
- [🛠 Requirements](#-requirements)
- [📦 Installation](#-installation)
- [🚀 Quick Start and How to Use](#-quick-start-and-how-to-use)
- [🎯 Usage Guide](#-usage-guide)
  - [UIKit Integration](#-uikit-integration)
  - [SwiftUI Integration](#-swiftui-integration)
  - [Hybrid UIKit & SwiftUI Usage](#-hybrid-uikit--swiftui-usage)
  - [Summary Table](#-summary-table)
- [📝 Version](#-version)
- [⚠️ Notes](#-notes)
- [🛠 Troubleshooting](#-troubleshooting)
- [👤 Author](#-author)

---

**AdsManagerKit** is a Swift Package designed to simplify the integration of [Google Mobile Ads (AdMob)](https://developers.google.com/admob/ios/quick-start) and [Google User Messaging Platform (UMP)](https://developers.google.com/admob/ump/ios/quick-start) in your iOS projects. It handles **App Tracking Transparency (ATT)**, **banner ads**, **interstitial ads**, **native ads**, and **app open ads** with minimal setup, allowing developers to focus on app functionality while maintaining compliance with privacy regulations.

---

## **✨ Features**

- Easy-to-integrate AdMob banner, interstitial, native, and app open ads.
- Automated handling of App Tracking Transparency (ATT) prompts.
- Google UMP consent collection support.
- Supports both **Production** and **Test** ad units.
- Swift Package Manager (SPM) compatible.
- Configurable ad error counters and ad display frequency.
- Asynchronous, safe ad loading to prevent crashes on iOS 14+.

## **🛠 Requirements**

- iOS 15+
- Swift 5.9+
- Xcode 26+
- Add the [`NSUserTrackingUsageDescription`](https://developer.apple.com/documentation/bundleresources/information_property_list/nsusertrackingusagedescription) key in your app’s Info.plist to prevent crashes with ATT.

## **📦 Installation**

### Swift Package Manager (SPM)

1. Open your project in Xcode.  
2. Go to **File > Add Packages…**  
3. Enter the repository URL:  
```swift
https://github.com/vishalvaghasiya-ios/AdsManagerKit.git
```
4. Select the desired version (latest stable recommended) and add it to your app target.  
5. Import into your Swift files:  
```swift
import AdsManager
```

## **🚀 Quick Start and How to Use**

Set up your ads by configuring ad unit IDs and enabling desired ad types using the new `configureAds` method:

```swift
// Configure Ads using the new method
AdsManager.configureAds(
    appOpenId: "YOUR_APP_OPEN_AD_UNIT_ID",
    bannerId: "YOUR_BANNER_AD_UNIT_ID",
    interstitialId: "YOUR_INTERSTITIAL_AD_UNIT_ID",
    nativeId: "YOUR_NATIVE_AD_UNIT_ID",
    openAdEnabled: true,
    bannerEnabled: true,
    interstitialEnabled: true,
    nativeEnabled: true,
    nativePreloadEnabled: true
)
```

*Note:* Using the completion handler of `AdsManager.configure` ensures that ads are loaded **after configuration is complete**, preventing timing issues during app startup.

```swift
// Then in your SplashScreen or initial view controller
AdsManager.configure {
    DispatchQueue.main.async {
        // Navigate or other action
    }
}
```

**Note:** If you enable premium mode, all ad-loading and displaying functions will automatically be skipped, effectively disabling ads throughout your app.

### Premium Mode (Optional)

You can enable or disable premium mode to stop or resume ads:

```swift
// Enable premium mode (ads disabled)
AdsManager.setToPremium(true)

// Disable premium mode (ads enabled)
AdsManager.setToPremium(false)
```

### Request App Tracking Permission (iOS 14+)

```swift
AdsManager.shared.requestAppTrackingPermission {
    print("ATT permission handled")
}
```

### Request UMP Consent

```swift
AdsManager.shared.requestUMPConsent { granted in
    print("User consent granted: \(granted)")
}
```

## **🎯 Usage Guide**

This section provides clear, segmented examples on how to use AdsManagerKit in both UIKit and SwiftUI, including hybrid usage scenarios. Examples cover Banner, Native, Interstitial, and App Open ads.

---

### **UIKit Integration**

#### Step 1: Configure Ads

```swift
import UIKit
import AdsManager

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        AdsManager.configureAds(
            appOpenId: "YOUR_APP_OPEN_AD_UNIT_ID",
            bannerId: "YOUR_BANNER_AD_UNIT_ID",
            interstitialId: "YOUR_INTERSTITIAL_AD_UNIT_ID",
            nativeId: "YOUR_NATIVE_AD_UNIT_ID",
            openAdEnabled: true,
            bannerEnabled: true,
            interstitialEnabled: true,
            nativeEnabled: true,
            nativePreloadEnabled: true
        )
        
        AdsManager.configure {
            print("Ads configured")
        }
        
        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        AdsManager.shared.presentAppOpenAdIfAvailable()
    }
}
```

#### Step 2: Banner Ads

##### Banner Ads

```swift
import UIKit
import AdsManager

class ViewController: UIViewController {
    @IBOutlet weak var bannerContainer: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()

        AdsManager.shared.loadBanner(in: bannerContainer, rootViewController: self) { isShown, height in
            print("Banner loaded: \(isShown), height: \(height)")
            // Optionally adjust bannerContainer height constraint here based on `height`
        }
    }
}
```

#### Step 3: Native Ads

```swift
import UIKit
import AdsManager

class ViewController: UIViewController {
    @IBOutlet weak var nativeContainer: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()

        AdsManager.shared.loadNative(in: nativeContainer, adType: .SMALL) { isLoaded in
            print("Native ad loaded: \(isLoaded)")
            // Optionally adjust nativeContainer height constraint here based on ad content
        }
    }
}
```

#### Step 4: Interstitial Ads

```swift
import UIKit
import AdsManager

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // No need to manually load interstitial ads anymore as they are preloaded during configuration
    }

    @IBAction func showInterstitialTapped(_ sender: UIButton) {
        AdsManager.shared.showInterstitial(from: self) {
            print("Interstitial dismissed")
        }
    }
}
```

#### Step 5: App Open Ads

Handled in `AppDelegate`'s `applicationDidBecomeActive` as shown above.

---

### **SwiftUI Integration**

#### Step 1: Configure Ads

```swift
import SwiftUI
import AdsManager

@main
struct MyApp: App {
    init() {
        AdsManager.configureAds(
            appOpenId: "YOUR_APP_OPEN_AD_UNIT_ID",
            bannerId: "YOUR_BANNER_AD_UNIT_ID",
            interstitialId: "YOUR_INTERSTITIAL_AD_UNIT_ID",
            nativeId: "YOUR_NATIVE_AD_UNIT_ID",
            openAdEnabled: true,
            bannerEnabled: true,
            interstitialEnabled: true,
            nativeEnabled: true,
            nativePreloadEnabled: true
        )
        
        AdsManager.configure {
            print("Ads configured")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    AdsManager.shared.presentAppOpenAdIfAvailable()
                }
        }
    }
}
```

#### Step 2: Banner Ads

##### Banner Ads

```swift
import SwiftUI
import AdsManager

struct ContentView: View {
    @State private var bannerHeight: CGFloat = 50

    var body: some View {
        VStack {
            Text("Welcome to My App")
                .font(.title)
                .padding()

            Spacer()

            BannerAdView(adType: .ADAPTIVE)
                .frame(height: bannerHeight)
                .onAppear {
                    // Optionally adjust bannerHeight dynamically if needed
                    // bannerHeight = calculatedHeight
                }

            Spacer()
        }
    }
}
```

#### Step 3: Native Ads

```swift
import SwiftUI
import AdsManager

struct ContentView: View {
    @State private var nativeAdHeight: CGFloat = 300

    var body: some View {
        VStack {
            Text("Native Ad Example")
                .font(.title)
                .padding()

            NativeAdContainerView(adType: .MEDIUM)
                .frame(height: nativeAdHeight)
                .onAppear {
                    // Adjust nativeAdHeight dynamically if needed
                    // nativeAdHeight = calculatedHeight
                }

            Spacer()
        }
        .padding()
    }
}
```

#### Step 4: Interstitial Ads

To show interstitial ads in SwiftUI, you need access to a `UIViewController` to present from. You can get it like this:

```swift
import SwiftUI
import UIKit

extension View {
    func rootViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else { return nil }
        return window.rootViewController
    }
}
```

Usage example:

```swift
Button("Show Interstitial Ad") {
    if let vc = rootViewController() {
        AdsManager.shared.showInterstitial(from: vc) {
            print("Interstitial dismissed")
        }
    }
}
```

// No need to call `AdsManager.shared.loadInterstitial()` manually as interstitial ads are preloaded during configuration.

#### Step 5: App Open Ads

Handled in the `.onAppear` of your main view or window group as shown in Step 1.

---

### **Hybrid UIKit & SwiftUI Usage**

You can mix UIKit and SwiftUI components seamlessly:

- Use UIKit for complex ad views or legacy code.
- Use SwiftUI wrappers (`BannerAdView`, `NativeAdContainerView`) for quick integration.
- Present interstitial and app open ads using UIKit view controllers accessed via SwiftUI.

Example: Embedding a SwiftUI `BannerAdView` inside a UIKit `UIViewController` via `UIHostingController` or showing interstitial ads from SwiftUI by retrieving the root view controller.

---

### **Summary Table**

| Ad Type          | UIKit Usage                                | SwiftUI Usage                          | Notes                                    |
|------------------|--------------------------------------------|--------------------------------------|------------------------------------------|
| Banner Ads       | `loadBanner(in:rootViewController:)`       | `BannerAdView(adType:)`               | Banner container UIView needed in UIKit  |
| Native Ads       | `loadNative(in:adType:completion:)`        | `NativeAdContainerView(adType:)`      | Adjust frame size based on ad type        |
| Interstitial Ads | `showInterstitial(from:)` (preloaded automatically) | Use `rootViewController()` + `showInterstitial(from:)` | Need UIViewController for presentation; interstitials preload automatically |
| App Open Ads     | Call `presentAppOpenAdIfAvailable()` in AppDelegate or scene | Call `presentAppOpenAdIfAvailable()` in `.onAppear` | Enable `openAdEnabled` in configuration   |

---

## **📝 Version**

### Version History

- **v1.0.0** - Initial release with support for banner, interstitial, native, and app open ads.
- **v1.1.0** - Added UMP consent support and premium mode.
- **v1.2.0** - Improved SwiftUI integration and added dynamic height support.
- **v1.3.0** - Bug fixes and performance improvements.

---

## **⚠️ Notes**

- Ensure [`NSUserTrackingUsageDescription`](https://developer.apple.com/documentation/bundleresources/information_property_list/nsusertrackingusagedescription) is added in your app’s Info.plist to prevent crashes with ATT.  
- Use Test Ad Units when `isProduction` is set to false.  
- Always request UMP consent before loading personalized ads in regions requiring GDPR compliance.

  
### **🛠 Add Google Mobile Ads App ID**

Add your **Google Mobile Ads Application ID** in your app's `Info.plist`:

```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY</string>
```

- Replace `ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY` with your actual AdMob App ID from the [AdMob Console](https://apps.admob.com/).
- Make sure the App ID is **unique to your app** and correctly formatted.
- This ID is required for all AdMob ads to function properly.

### **Disable Native Ad Validator (Optional)**

If you want to disable the Native Ad Validator in your app, add the following key to your `Info.plist`:

```xml
<key>GADNativeAdValidatorEnabled</key>
<false/>
```

- This is optional and generally used to prevent validation logs in production.

---

## **🛠 Troubleshooting**

- **Ads not showing:**  
  Ensure your ad unit IDs are correct and that you have enabled the respective ad types in `configureAds`. Use test ad units during development.

- **App crashes on ATT permission request:**  
  Verify that `NSUserTrackingUsageDescription` is set in your Info.plist.

- **UMP Consent not appearing:**  
  Confirm that you have correctly implemented `requestUMPConsent` and that your app region requires GDPR consent.

- **Banner or Native ad height issues:**  
  Use dynamic height adjustments in SwiftUI with `@State` variables as shown in the examples.

- **Interstitial ads not presenting:**  
  Make sure you present from a valid `UIViewController` and that the interstitial ad has finished loading before showing.

---

## **👤 Author**

Vishal Vaghasiya  
GitHub: [vishalvaghasiya-ios](https://github.com/vishal-vaghasiya)
