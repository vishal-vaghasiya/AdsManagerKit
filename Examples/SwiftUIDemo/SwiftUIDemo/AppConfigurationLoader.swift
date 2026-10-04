import Foundation
import AdsManagerKit

enum AppConfigurationLoader {

    static func load() -> AppConfiguration? {
        guard let url = Bundle.main.url(
            forResource: "appConfiguration",
            withExtension: "json"
        ) else {
            print("❌ appConfiguration.json not found")
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let configuration = try JSONDecoder().decode(
                AppConfiguration.self,
                from: data
            )

            return configuration

        } catch {
            print("❌ Failed to decode AppConfiguration: \(error)")
            return nil
        }
    }
}
