import UIKit
import GoogleMobileAds
import AdsManagerKit
class FeedViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, NativeAdLoaderOutput {
    
    // MARK: - Properties
    
    private var items: [FeedItem] = []
    private var nativeAds: [NativeAd] = []
    private let adInterval = 5
    @IBOutlet weak var tableView: UITableView!
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Feed"
        
        setupTableView()
        createDemoData()
        loadNativeAds()
    }
    
    // MARK: - Setup
    
    private func setupTableView() {
        tableView.dataSource = self
        tableView.delegate = self
        
        tableView.register(FeedCell.self,
                           forCellReuseIdentifier: FeedCell.reuseIdentifier)
        
        tableView.register(NativeAdTableViewCell.self,
                           forCellReuseIdentifier:
                            NativeAdTableViewCell.reuseIdentifier)
        
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 200
    }
    
    // MARK: - Demo Data
    private func createDemoData() {
        items = (1...30).map { index in
            FeedItem(
                id: index,
                title: "Feed Item \(index)",
                subtitle: "This is the description for feed item \(index)."
            )
        }
    }
    
    // MARK: - Native Ads
    private func loadNativeAds() {
        InlineNativeAdManager.shared.loadNativeAds(count: 5, rootViewController: self) { [weak self] ads in
            guard let self else {
                return
            }
            print("Finished loading \(ads.count) native ads")
            // This contains all successfully loaded ads.
            self.nativeAds = ads
            self.tableView.reloadData()
        }
    }
    
    // MARK: - NativeAdLoaderOutput
    
    func nativeAdLoader(_ loader: InlineNativeAdManager, didLoad ad: NativeAd) {
        // This is called immediately for every ad.
        print("Native ad loaded")
        nativeAds.append(ad)
        
        // Update the list immediately.
        tableView.reloadData()
    }
    
    func nativeAdLoader(_ loader: InlineNativeAdManager, didFailWith error: Error) {
        print("Native ad failed:", error.localizedDescription)
    }
    
    // MARK: - UITableViewDataSource
    
    func tableView(_ tableView: UITableView,numberOfRowsInSection section: Int) -> Int {
        return items.count + nativeAds.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Check if this row represents an ad.
        if let adIndex = nativeAdIndex(for: indexPath) {
            guard adIndex < nativeAds.count else {
                return UITableViewCell()
            }
            
            let cell = tableView.dequeueReusableCell(withIdentifier: NativeAdTableViewCell.reuseIdentifier, for: indexPath) as! NativeAdTableViewCell
            cell.configure(with: nativeAds[adIndex])
            return cell
        }
        
        // Normal content cell.
        let contentIndex = contentIndex(for: indexPath)
        let cell = tableView.dequeueReusableCell(withIdentifier: FeedCell.reuseIdentifier, for: indexPath) as! FeedCell
        cell.configure(with: items[contentIndex])
        return cell
    }
    
    // MARK: - Ad Position
    
    private func nativeAdIndex(for indexPath: IndexPath) -> Int? {
        let row = indexPath.row
        guard row > 0 else {
            return nil
        }
        
        let position = row + 1
        
        guard position % (adInterval + 1) == 0 else {
            return nil
        }
        
        let adIndex = (position / (adInterval + 1)) - 1
        
        guard adIndex >= 0,
              adIndex < nativeAds.count else {
            return nil
        }
        
        return adIndex
    }
    
    // MARK: - Content Position
    
    private func contentIndex(for indexPath: IndexPath) -> Int {
        let row = indexPath.row
        
        let adsBeforeRow =
        row / (adInterval + 1)
        
        return row - adsBeforeRow
    }
}
