import UIKit
import GoogleMobileAds
import AdsManagerKit

@MainActor
final class ListViewController: UIViewController {

    // MARK: - Properties

    @IBOutlet weak var tableView: UITableView!

    private let items: [String] = [
        "Item 1",
        "Item 2",
        "Item 3",
        "Item 4",
        "Item 5",
        "Item 6",
        "Item 7",
        "Item 8",
        "Item 9",
        "Item 10",
        "Item 11",
        "Item 12",
        "Item 13",
        "Item 14",
        "Item 15",
        "Item 16",
        "Item 17",
        "Item 18",
        "Item 19",
        "Item 20"
    ]

    /// Insert an ad after every 4 normal items.
    private let adInterval = 4

    /// Successfully loaded banners.
    private var loadedBanners: [Int: BannerView] = [:]

    /// Height for each loaded banner.
    private var bannerHeights: [Int: CGFloat] = [:]

    /// Prevents starting the loading process multiple times
    /// from `viewDidLayoutSubviews`.
    private var isAdLoadingStarted = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Items"

        setupTableView()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        setupAndLoadAdsIfNeeded()
    }

    override func viewDidDisappear(
        _ animated: Bool
    ) {
        super.viewDidDisappear(animated)

        InlineBannerAdManager.shared.reset()

        loadedBanners.removeAll()
        bannerHeights.removeAll()

        isAdLoadingStarted = false
    }

    // MARK: - Setup

    private func setupTableView() {

        tableView.delegate = self
        tableView.dataSource = self

        tableView.register(
            UITableViewCell.self,
            forCellReuseIdentifier: "Cell"
        )

        tableView.register(
            InlineBannerTableViewCell.self,
            forCellReuseIdentifier: "InlineBannerCell"
        )

        tableView.separatorStyle = .singleLine

        tableView.rowHeight =
            UITableView.automaticDimension

        tableView.estimatedRowHeight = 50
    }

    // MARK: - Ads

    private func setupAndLoadAdsIfNeeded() {

        guard !isAdLoadingStarted else {
            return
        }

        let width = tableView.bounds.width

        guard width > 0 else {
            return
        }

        isAdLoadingStarted = true

        let manager = InlineBannerAdManager.shared

        manager.output = self

        manager.loadBannerAds(
            count: adCount,
            rootViewController: self,
            width: width
        ) { [weak self] banners in

            guard let self else {
                return
            }

            #if DEBUG
            print(
                "[ListViewController] " +
                "All banner loading completed. " +
                "Loaded: \(banners.count)/\(self.adCount)"
            )
            #endif
        }
    }

    private func updateAdWidth() {

        let width = tableView.bounds.width

        guard width > 0 else {
            return
        }

        InlineBannerAdManager.shared.updateWidth(
            width
        )
    }

    // MARK: - Ad Count

    /// Number of ads required for the list.
    ///
    /// 20 items / 4 = 5 ads.
    private var adCount: Int {

        guard adInterval > 0 else {
            return 0
        }

        return items.count / adInterval
    }

    // MARK: - Row Mapping

    /// Determines whether a table row is an ad row.
    ///
    /// With `adInterval = 4`:
    ///
    /// Row 0 → Item 1
    /// Row 1 → Item 2
    /// Row 2 → Item 3
    /// Row 3 → Item 4
    /// Row 4 → Ad 0
    /// Row 5 → Item 5
    /// Row 6 → Item 6
    /// Row 7 → Item 7
    /// Row 8 → Item 8
    /// Row 9 → Ad 1
    private func isAdRow(
        _ row: Int
    ) -> Bool {

        guard row > 0 else {
            return false
        }

        return row % (adInterval + 1) == adInterval
    }

    /// Returns the ad index for a table row.
    ///
    /// Example:
    ///
    /// Row 4 → Ad 0
    /// Row 9 → Ad 1
    /// Row 14 → Ad 2
    private func adIndex(
        forRow row: Int
    ) -> Int? {

        guard isAdRow(row) else {
            return nil
        }

        return row / (adInterval + 1)
    }

    /// Returns the item index for a table row.
    private func itemIndex(
        forRow row: Int
    ) -> Int? {

        guard !isAdRow(row) else {
            return nil
        }

        let adsBeforeRow =
            row / (adInterval + 1)

        let itemIndex =
            row - adsBeforeRow

        guard itemIndex >= 0,
              itemIndex < items.count else {
            return nil
        }

        return itemIndex
    }

    /// Returns the table row for an ad index.
    ///
    /// Example:
    ///
    /// Ad 0 → Row 4
    /// Ad 1 → Row 9
    /// Ad 2 → Row 14
    private func row(
        forAdIndex adIndex: Int
    ) -> Int {

        return (
            adIndex * (adInterval + 1)
        ) + adInterval
    }
}

// MARK: - InlineBannerAdLoaderOutput

extension ListViewController:
    InlineBannerAdLoaderOutput {

    /// Called immediately whenever one banner is successfully loaded.
    func inlineBannerAdLoader(
        _ loader: InlineBannerAdManager,
        didLoad bannerView: BannerView,
        at index: Int,
        height: CGFloat
    ) {

        loadedBanners[index] = bannerView

        bannerHeights[index] = height

        #if DEBUG
        print(
            "[ListViewController] " +
            "Banner loaded. " +
            "Index: \(index), " +
            "Height: \(height)"
        )
        #endif

        let adRow = row(
            forAdIndex: index
        )

        guard adRow <
                tableView.numberOfRows(
                    inSection: 0
                ) else {
            return
        }

        let indexPath = IndexPath(
            row: adRow,
            section: 0
        )

        // Reload only this newly loaded ad.
        tableView.reloadRows(
            at: [indexPath],
            with: .none
        )
    }

    /// Called whenever one banner fails.
    func inlineBannerAdLoader(
        _ loader: InlineBannerAdManager,
        didFailWith error: Error,
        at index: Int
    ) {

        #if DEBUG
        print(
            "[ListViewController] " +
            "Banner failed. " +
            "Index: \(index), " +
            "Error: \(error.localizedDescription)"
        )
        #endif

        loadedBanners.removeValue(
            forKey: index
        )

        bannerHeights.removeValue(
            forKey: index
        )

        let adRow = row(
            forAdIndex: index
        )

        guard adRow <
                tableView.numberOfRows(
                    inSection: 0
                ) else {
            return
        }

        let indexPath = IndexPath(
            row: adRow,
            section: 0
        )

        // Keep the failed ad row hidden.
        tableView.reloadRows(
            at: [indexPath],
            with: .none
        )
    }
}

// MARK: - UITableViewDataSource

extension ListViewController:
    UITableViewDataSource {

    func tableView(
        _ tableView: UITableView,
        numberOfRowsInSection section: Int
    ) -> Int {

        return items.count + adCount
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {

        // MARK: Ad Cell

        if let adIndex = adIndex(
            forRow: indexPath.row
        ) {

            let cell =
                tableView.dequeueReusableCell(
                    withIdentifier: "InlineBannerCell",
                    for: indexPath
                ) as! InlineBannerTableViewCell

            if let bannerView =
                loadedBanners[adIndex] {

                cell.configure(
                    with: bannerView
                )

            } else {

                cell.clearBanner()
            }

            return cell
        }

        // MARK: Normal Cell

        let cell =
            tableView.dequeueReusableCell(
                withIdentifier: "Cell",
                for: indexPath
            )

        if let itemIndex =
            itemIndex(
                forRow: indexPath.row
            ) {

            cell.textLabel?.text =
                items[itemIndex]

        } else {

            cell.textLabel?.text = nil
        }

        return cell
    }
}

// MARK: - UITableViewDelegate

extension ListViewController:
    UITableViewDelegate {

    func tableView(
        _ tableView: UITableView,
        heightForRowAt indexPath: IndexPath
    ) -> CGFloat {

        // Normal item.
        guard let adIndex =
                adIndex(
                    forRow: indexPath.row
                ) else {

            return UITableView.automaticDimension
        }

        // Ad has not loaded yet.
        guard loadedBanners[adIndex] != nil else {
            return 0
        }

        // Return the adaptive height of this specific ad.
        return bannerHeights[adIndex] ?? 0
    }
}
