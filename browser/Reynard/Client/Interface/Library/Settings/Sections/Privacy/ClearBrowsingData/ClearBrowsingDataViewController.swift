//
//  ClearBrowsingDataViewController.swift
//  Reynard
//
//  Created by Minh Ton on 23/6/26.
//

import GeckoView
import UIKit

final class ClearBrowsingDataViewController: SettingsTableViewController {
    private enum UX {
        static let actionRowHeight: CGFloat = 88
    }
    
    private enum Section: CaseIterable {
        case data
        case action
    }
    
    private enum BrowsingDataCategory: CaseIterable {
        case browsingHistory
        case cookiesAndWebsiteData
        case cachedImagesAndFiles
        case downloadsHistory
        case downloadedFiles
        case websitePermissions
        case openedTabs
        
        var title: String {
            switch self {
            case .browsingHistory:
                return "Browsing History"
            case .cookiesAndWebsiteData:
                return "Cookies and Website Data"
            case .cachedImagesAndFiles:
                return "Cached Images and Files"
            case .downloadsHistory:
                return "Downloads History"
            case .downloadedFiles:
                return "Downloaded Files"
            case .websitePermissions:
                return "Website Permissions"
            case .openedTabs:
                return "Opened Tabs"
            }
        }
        
        var subtitle: String? {
            switch self {
            case .browsingHistory:
                let count = HistoryStore.shared.currentSnapshot().items.count
                return "\(count) \(count == 1 ? "address" : "addresses")"
            case .cookiesAndWebsiteData:
                return "You'll be logged out of most sites"
            case .cachedImagesAndFiles:
                return "Frees up storage space"
            case .downloadsHistory:
                return nil
            case .downloadedFiles:
                return nil
            case .websitePermissions:
                return nil
            case .openedTabs:
                return nil
            }
        }
        
        var isSelected: Bool {
            switch self {
            case .browsingHistory:
                return Prefs.ClearBrowsingData.clearsBrowsingHistory
            case .cookiesAndWebsiteData:
                return Prefs.ClearBrowsingData.clearsCookiesAndWebsiteData
            case .cachedImagesAndFiles:
                return Prefs.ClearBrowsingData.clearsCachedImagesAndFiles
            case .downloadsHistory:
                return Prefs.ClearBrowsingData.clearsDownloadsHistory
            case .downloadedFiles:
                return Prefs.ClearBrowsingData.clearsDownloadedFiles
            case .websitePermissions:
                return Prefs.ClearBrowsingData.clearsWebsitePermissions
            case .openedTabs:
                return Prefs.ClearBrowsingData.clearsOpenedTabs
            }
        }
        
        func setSelected(_ isSelected: Bool) {
            switch self {
            case .browsingHistory:
                Prefs.ClearBrowsingData.clearsBrowsingHistory = isSelected
            case .cookiesAndWebsiteData:
                Prefs.ClearBrowsingData.clearsCookiesAndWebsiteData = isSelected
            case .cachedImagesAndFiles:
                Prefs.ClearBrowsingData.clearsCachedImagesAndFiles = isSelected
            case .downloadsHistory:
                Prefs.ClearBrowsingData.clearsDownloadsHistory = isSelected
            case .downloadedFiles:
                Prefs.ClearBrowsingData.clearsDownloadedFiles = isSelected
            case .websitePermissions:
                Prefs.ClearBrowsingData.clearsWebsitePermissions = isSelected
            case .openedTabs:
                Prefs.ClearBrowsingData.clearsOpenedTabs = isSelected
            }
        }
    }
    
    private let browsingDataCategorySwitches = BrowsingDataCategory.allCases.reduce(into: [BrowsingDataCategory: UISwitch]()) { result, category in
        let toggle = UISwitch()
        toggle.isOn = category.isSelected
        result[category] = toggle
    }
    
    private lazy var clearBrowsingDataFooterView = ClearDataFooterView(
        title: "Clear Browsing Data",
        target: self,
        action: #selector(confirmClearBrowsingData)
    )
    
    init() {
        super.init(style: .insetGrouped)
        title = "Clear Browsing Data"
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemGroupedBackground
        navigationItem.largeTitleDisplayMode = .never
        
        for category in BrowsingDataCategory.allCases {
            browsingDataCategorySwitches[category]?.addTarget(self, action: #selector(categorySwitchChanged), for: .valueChanged)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadSections(IndexSet(integer: 0), with: .none)
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard Section.allCases.indices.contains(section) else {
            return 0
        }
        
        switch Section.allCases[section] {
        case .data:
            return BrowsingDataCategory.allCases.count
        case .action:
            return 1
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard Section.allCases.indices.contains(indexPath.section) else {
            return UITableViewCell()
        }
        
        switch Section.allCases[indexPath.section] {
        case .data:
            guard BrowsingDataCategory.allCases.indices.contains(indexPath.row) else {
                return UITableViewCell()
            }
            return categoryCell(for: BrowsingDataCategory.allCases[indexPath.row])
        case .action:
            return clearActionCell()
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 1 {
            return UX.actionRowHeight
        }
        
        return UITableView.automaticDimension
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer {
            tableView.deselectRow(at: indexPath, animated: true)
        }
        
        guard indexPath.section == 0,
              BrowsingDataCategory.allCases.indices.contains(indexPath.row) else {
            return
        }
        
        let category = BrowsingDataCategory.allCases[indexPath.row]
        setSelected(!category.isSelected, for: category)
    }
    
    private func categoryCell(for category: BrowsingDataCategory) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.textLabel?.text = category.title
        cell.detailTextLabel?.text = category.subtitle
        cell.detailTextLabel?.textColor = .secondaryLabel
        cell.detailTextLabel?.numberOfLines = 0
        browsingDataCategorySwitches[category]?.isOn = category.isSelected
        cell.accessoryView = browsingDataCategorySwitches[category]
        cell.selectionStyle = .default
        return cell
    }
    
    private func clearActionCell() -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear
        cell.selectionStyle = .none
        cell.contentView.addSubview(clearBrowsingDataFooterView)
        clearBrowsingDataFooterView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            clearBrowsingDataFooterView.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor),
            clearBrowsingDataFooterView.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor),
            clearBrowsingDataFooterView.topAnchor.constraint(equalTo: cell.contentView.topAnchor),
            clearBrowsingDataFooterView.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor),
        ])
        return cell
    }
    
    private func setSelected(_ isSelected: Bool, for category: BrowsingDataCategory) {
        category.setSelected(isSelected)
        browsingDataCategorySwitches[category]?.setOn(isSelected, animated: true)
    }
    
    @objc private func categorySwitchChanged(_ sender: UISwitch) {
        guard let category = browsingDataCategorySwitches.first(where: { $0.value === sender })?.key else {
            return
        }
        
        setSelected(sender.isOn, for: category)
    }
    
    @objc private func confirmClearBrowsingData() {
        AlertPresenter.show(
            title: nil,
            message: "This action will clear all of your browsing data. It cannot be undone.",
            buttons: [
                AlertPresenter.Button(title: "OK", style: .destructive) { [weak self] in
                    self?.clearSelectedData()
                },
                AlertPresenter.Button(title: "Cancel"),
            ]
        )
    }
    
    private func clearSelectedData() {
        let selectedCategories = Set(BrowsingDataCategory.allCases.filter(\.isSelected))
        
        if selectedCategories.contains(.browsingHistory) {
            HistoryStore.shared.clearVisits(since: nil)
        }
        
        if selectedCategories.contains(.downloadsHistory) {
            DownloadStore.shared.clearCompletedDownloads(since: nil)
        }
        
        if selectedCategories.contains(.downloadedFiles) {
            DownloadStore.shared.clearCompletedDownloadFiles()
        }
        
        if selectedCategories.contains(.cachedImagesAndFiles) {
            FaviconStore.shared.clearCache()
        }
        
        if selectedCategories.contains(.websitePermissions) {
            SiteSettingsUtils.resetStoredSitePermissions()
        }
        
        if selectedCategories.contains(.openedTabs) {
            clearOpenedTabs()
        }
        
        Task {
            await clearSelectedEngineData(for: selectedCategories)
        }
    }
    
    private func clearOpenedTabs() {
        guard let browserViewController = LibrarySharedUtils.resolvedBrowserViewController(from: self) else {
            return
        }
        
        browserViewController.tabManager.removeAllTabs(mode: .regular)
        browserViewController.tabManager.removeAllTabs(mode: .private)
        browserViewController.tabManager.createTab(selecting: true, mode: .regular)
    }
    
    private func clearSelectedEngineData(for selectedCategories: Set<BrowsingDataCategory>) async {
        do {
            if selectedCategories.contains(.cookiesAndWebsiteData) {
                try await GeckoStorageController.clearData(
                    flags: GeckoStorageClearFlags.cookies | GeckoStorageClearFlags.authSessions
                )
                try await GeckoStorageController.clearData(flags: GeckoStorageClearFlags.domStorages)
            }
            
            if selectedCategories.contains(.cachedImagesAndFiles) {
                await GeckoStorageController.clearTranslationModelCache()
                try await GeckoStorageController.clearData(flags: GeckoStorageClearFlags.allCaches)
            }
        } catch {
            AlertPresenter.show(title: "Failed to clear browsing data", message: "\(error)")
        }
    }
}
