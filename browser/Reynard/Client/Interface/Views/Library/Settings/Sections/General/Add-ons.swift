//
//  Add-ons.swift
//  Reynard
//
//  Created by Minh Ton on 15/5/26.
//

import GeckoView
import UIKit
import UniformTypeIdentifiers
import MobileCoreServices

final class AddonsPreferencesViewController: SettingsTableViewController {
    private enum Section: Int, CaseIterable {
        case installed
        case more
    }
    
    private static let sharedIconCache = NSCache<NSString, UIImage>()
    private static let hiddenAddonIDs: Set<String> = ["default-theme@mozilla.org"]
    private static var hasLoadedInstalledAddons = false
    
    private let iconLoadingQueue = DispatchQueue(label: "com.minh-ton.addons-settings-icon-queue", qos: .utility)
    private var iconLoadingIDs = Set<String>()
    private var addons: [Addon] = []
    private var isLoadingAddons = false
    private var isInstallingAddonFromFile = false
    
    init() {
        super.init(style: .insetGrouped)
        title = "Add-ons"
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Self.sharedIconCache.countLimit = 64
        syncAddonsFromCache()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        syncAddonsFromCache()
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .installed:
            return addons.isEmpty ? 1 : addons.count
        case .more:
            return 2
        case nil:
            return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section) {
        case .installed:
            if addons.isEmpty {
                let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
                cell.selectionStyle = .none
                cell.textLabel?.text = isLoadingAddons ? "Loading Add-ons..." : "No Add-ons Installed"
                cell.textLabel?.textColor = .secondaryLabel
                return cell
            }
            
            guard addons.indices.contains(indexPath.row) else {
                return UITableViewCell()
            }
            
            let addon = addons[indexPath.row]
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = addon.metaData.name ?? addon.id
            cell.accessoryType = .disclosureIndicator
            cell.imageView?.image = Self.sharedIconCache.object(forKey: addon.id as NSString) ?? UIImage(systemName: "puzzlepiece.extension")
            loadIconIfNeeded(for: addon)
            return cell
        case .more:
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            switch indexPath.row {
            case 0:
                cell.textLabel?.text = "Discover Add-ons..."
                cell.textLabel?.textColor = view.tintColor
            case 1:
                cell.textLabel?.text = isInstallingAddonFromFile ? "Installing Add-on..." : "Install Add-on From File..."
                cell.textLabel?.textColor = isInstallingAddonFromFile ? .secondaryLabel : view.tintColor
                if isInstallingAddonFromFile {
                    cell.selectionStyle = .none
                }
            default:
                return cell
            }
            
            return cell
        case nil:
            return UITableViewCell()
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer { tableView.deselectRow(at: indexPath, animated: true) }
        
        switch Section(rawValue: indexPath.section) {
        case .installed:
            guard let addon = installedAddon(at: indexPath) else {
                return
            }
            navigationController?.pushViewController(
                AddonDetailsPreferencesViewController(addonID: addon.id),
                animated: true
            )
        case .more:
            switch indexPath.row {
            case 0:
                openLinkInBrowser("https://addons.mozilla.org/android/")
            case 1:
                guard !isInstallingAddonFromFile else {
                    return
                }
                presentAddonFilePicker()
            default:
                return
            }
        case nil:
            return
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard Section(rawValue: section) == .installed,
              !addons.isEmpty else {
            return nil
        }
        return "Installed Add-ons"
    }
    
    private func syncAddonsFromCache() {
        addons = AddonsRuntime.shared.installedAddons.filter { !Self.hiddenAddonIDs.contains($0.id) }
        if addons.isEmpty && !Self.hasLoadedInstalledAddons {
            guard !isLoadingAddons else {
                return
            }
            isLoadingAddons = true
            tableView.reloadData()
            Task { [weak self] in
                await self?.reloadAddonsFromRuntime()
            }
            return
        }
        
        isLoadingAddons = false
        tableView.reloadData()
    }
    
    private func reloadAddonsFromRuntime() async {
        let refreshedAddons: [Addon]
        do {
            refreshedAddons = try await AddonsRuntime.shared.list()
        } catch {
            refreshedAddons = AddonsRuntime.shared.installedAddons
        }
        
        await MainActor.run {
            Self.hasLoadedInstalledAddons = true
            self.addons = refreshedAddons.filter { !Self.hiddenAddonIDs.contains($0.id) }
            self.isLoadingAddons = false
            self.tableView.reloadData()
        }
    }
    
    private func installedAddon(at indexPath: IndexPath) -> Addon? {
        guard Section(rawValue: indexPath.section) == .installed,
              !addons.isEmpty,
              addons.indices.contains(indexPath.row) else {
            return nil
        }
        return addons[indexPath.row]
    }
    
    private func presentAddonFilePicker() {
        let picker: UIDocumentPickerViewController
        if #available(iOS 14.0, *) {
            picker = UIDocumentPickerViewController(forOpeningContentTypes: Self.allowedAddonFileTypes(), asCopy: true)
        } else {
            picker = UIDocumentPickerViewController(documentTypes: Self.allowedAddonDocumentTypeIdentifiers(), in: .import)
        }
        if #available(iOS 13.0, *) {
            picker.shouldShowFileExtensions = true
        }
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }
    
    private func installAddon(from sourceURL: URL) {
        isInstallingAddonFromFile = true
        tableView.reloadSections(IndexSet(integer: Section.more.rawValue), with: .none)
        
        Task { [weak self] in
            guard let self else {
                return
            }
            
            do {
                let stagedURL = try Self.stageAddonPackage(from: sourceURL)
                _ = try await AddonsRuntime.shared.install(url: stagedURL.absoluteString)
                await self.reloadAddonsFromRuntime()
                
                await MainActor.run {
                    self.isInstallingAddonFromFile = false
                    self.tableView.reloadSections(IndexSet(integer: Section.more.rawValue), with: .none)
                }
            } catch {
                await MainActor.run {
                    self.isInstallingAddonFromFile = false
                    self.tableView.reloadSections(IndexSet(integer: Section.more.rawValue), with: .none)
                    guard !Self.isUserCancelledAddonInstall(error) else {
                        return
                    }
                    self.presentAlert(title: "Failed to install add-on", message: "\(error)")
                }
            }
        }
    }
    
    private static func isUserCancelledAddonInstall(_ error: Error) -> Bool {
        guard let value = Mirror(reflecting: error).descendant("value") as? [String: Any?] else {
            return false
        }
        
        let cancelledByUser: Int?
        if let number = value["cancelledByUser"] as? NSNumber {
            cancelledByUser = number.intValue
        } else {
            cancelledByUser = value["cancelledByUser"] as? Int
        }
        
        let installError: Int?
        if let number = value["installError"] as? NSNumber {
            installError = number.intValue
        } else {
            installError = value["installError"] as? Int
        }
        
        return cancelledByUser == 1 && installError == 0
    }
    
    @available(iOS 14.0, *)
    private static func allowedAddonFileTypes() -> [UTType] {
        if let xpiType = UTType(filenameExtension: "xpi") {
            return [xpiType]
        }
        
        return [UTType(importedAs: "org.mozilla.xpi-extension")]
    }
    
    private static func allowedAddonDocumentTypeIdentifiers() -> [String] {
        var identifiers: [String] = []
        
        ["xpi"].forEach { ext in
            if let typeIdentifier = UTTypeCreatePreferredIdentifierForTag(
                kUTTagClassFilenameExtension,
                ext as CFString,
                nil
            )?.takeRetainedValue() as String?,
               !identifiers.contains(typeIdentifier) {
                identifiers.append(typeIdentifier)
            }
        }
        
        return identifiers
    }
    
    private static func stageAddonPackage(from sourceURL: URL) throws -> URL {
        let fileManager = FileManager.default
        let directoryURL = fileManager.temporaryDirectory.appendingPathComponent("Addons", isDirectory: true)
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        
        let destinationURL = directoryURL
            .appendingPathComponent(UUID().uuidString, isDirectory: false)
            .appendingPathExtension("xpi")
        
        let accessed = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }
        
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }
    
    private func loadIconIfNeeded(for addon: Addon) {
        let cacheKey = addon.id as NSString
        guard Self.sharedIconCache.object(forKey: cacheKey) == nil,
              iconLoadingIDs.contains(addon.id) == false,
              addon.metaData.iconURL != nil else {
            return
        }
        
        iconLoadingIDs.insert(addon.id)
        let iconURL = addon.metaData.iconURL
        iconLoadingQueue.async { [weak self] in
            guard let self else {
                return
            }
            
            let image = AddonIconLoader.loadImage(from: iconURL, targetSize: CGSize(width: 24, height: 24))
            DispatchQueue.main.async {
                self.iconLoadingIDs.remove(addon.id)
                if let image {
                    Self.sharedIconCache.setObject(image, forKey: cacheKey)
                }
                
                guard let currentRow = self.addons.firstIndex(where: { $0.id == addon.id }) else {
                    return
                }
                
                let currentIndexPath = IndexPath(row: currentRow, section: Section.installed.rawValue)
                guard let cell = self.tableView.cellForRow(at: currentIndexPath) else {
                    return
                }
                
                cell.imageView?.image = image ?? UIImage(systemName: "puzzlepiece.extension")
                cell.setNeedsLayout()
            }
        }
    }
}

extension AddonsPreferencesViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else {
            return
        }
        
        installAddon(from: url)
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {}
}

final class AddonDetailsPreferencesViewController: SettingsTableViewController {
    private enum Section {
        case status
        case actions
        case destinations
    }
    
    private enum ActionRow {
        case enabled
        case privateBrowsing
        case settings
        case details
        case permissions
        case remove
    }
    
    private struct StatusMessage {
        let text: String
        let color: UIColor
    }
    
    private let addonID: String
    private let enableSwitch = UISwitch()
    private let privateBrowsingSwitch = UISwitch()
    private var addon: Addon?
    private var isUpdatingAddon = false
    
    private var visibleSections: [Section] {
        var sections: [Section] = []
        if statusMessage != nil {
            sections.append(.status)
        }
        sections.append(.actions)
        if !navigationRows.isEmpty {
            sections.append(.destinations)
        }
        return sections
    }
    
    private var actionRows: [ActionRow] {
        var rows: [ActionRow] = [.enabled]
        
        if addon?.metaData.enabled == true {
            rows.append(.privateBrowsing)
        }
        return rows
    }
    
    private var navigationRows: [ActionRow] {
        var rows: [ActionRow] = []
        
        if optionsPageURL != nil {
            rows.append(.settings)
        }
        
        rows.append(contentsOf: [.details, .permissions, .remove])
        return rows
    }
    
    private var optionsPageURL: String? {
        guard let value = addon?.metaData.optionsPageURL?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty,
              URL(string: value) != nil else {
            return nil
        }
        return value
    }
    
    private var statusMessage: StatusMessage? {
        guard let addon else {
            return nil
        }
        
        let metaData = addon.metaData
        if metaData.isBlocklisted {
            return StatusMessage(
                text: "This extension is blocked for violating Mozilla's policies and has been disabled.",
                color: .systemRed
            )
        }
        
        if metaData.isUnsigned {
            let addonName = metaData.name ?? addon.id
            return StatusMessage(
                text: "\(addonName) could not be verified as secure and has been disabled.",
                color: .systemRed
            )
        }
        
        if metaData.isIncompatible {
            let addonName = metaData.name ?? addon.id
            let appName = (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? "the browser"
            let appVersion = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
            ?? "Unknown"
            return StatusMessage(
                text: "\(addonName) is not compatible with your version of \(appName) (version \(appVersion)).",
                color: .systemOrange
            )
        }
        
        if metaData.isSoftBlocked {
            return StatusMessage(
                text: metaData.enabled
                ? "This extension is restricted. Using it may be risky."
                : "This extension is restricted and has been disabled. You can enable it, but this may be risky.",
                color: .systemOrange
            )
        }
        
        return nil
    }
    
    init(addonID: String) {
        self.addonID = addonID
        super.init(style: .insetGrouped)
        title = "Add-on"
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        enableSwitch.isEnabled = false
        enableSwitch.addTarget(self, action: #selector(enableSwitchChanged(_:)), for: .valueChanged)
        privateBrowsingSwitch.isEnabled = false
        privateBrowsingSwitch.addTarget(self, action: #selector(privateBrowsingSwitchChanged(_:)), for: .valueChanged)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Task { [weak self] in
            await self?.reloadAddon()
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        visibleSections.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard visibleSections.indices.contains(section) else {
            return 0
        }
        
        switch visibleSections[section] {
        case .status:
            return 1
        case .actions:
            return actionRows.count
        case .destinations:
            return navigationRows.count
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard visibleSections.indices.contains(indexPath.section) else {
            return UITableViewCell()
        }
        
        switch visibleSections[indexPath.section] {
        case .status:
            return statusCell()
        case .actions:
            return actionCell(for: indexPath)
        case .destinations:
            return navigationCell(for: indexPath)
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer { tableView.deselectRow(at: indexPath, animated: true) }
        
        guard visibleSections.indices.contains(indexPath.section),
              let addon,
              !isUpdatingAddon else {
            return
        }
        
        switch visibleSections[indexPath.section] {
        case .status:
            return
        case .actions:
            guard actionRows.indices.contains(indexPath.row) else {
                return
            }
            
            switch actionRows[indexPath.row] {
            case .enabled, .privateBrowsing:
                return
            case .settings, .details, .permissions, .remove:
                return
            }
        case .destinations:
            guard navigationRows.indices.contains(indexPath.row) else {
                return
            }
            
            switch navigationRows[indexPath.row] {
            case .settings:
                guard let optionsPageURL else {
                    return
                }
                openLinkInBrowser(optionsPageURL)
            case .details:
                navigationController?.pushViewController(AddonInformationPreferencesViewController(addonID: addon.id), animated: true)
            case .permissions:
                navigationController?.pushViewController(AddonPermissionsPreferencesViewController(addonID: addon.id), animated: true)
            case .remove:
                presentRemoveConfirmation()
            case .enabled, .privateBrowsing:
                return
            }
        }
    }
    
    @objc private func privateBrowsingSwitchChanged(_ sender: UISwitch) {
        let desiredState = sender.isOn
        
        Task { [weak self] in
            guard let self, let addon = self.addon else {
                await MainActor.run {
                    sender.setOn(!desiredState, animated: true)
                }
                return
            }
            
            await MainActor.run {
                self.isUpdatingAddon = true
                self.tableView.reloadData()
            }
            
            do {
                let updatedAddon = try await AddonsRuntime.shared.setAllowedInPrivateBrowsing(addon, allowed: desiredState)
                
                await MainActor.run {
                    self.isUpdatingAddon = false
                    self.apply(addon: updatedAddon)
                }
            } catch {
                await MainActor.run {
                    self.isUpdatingAddon = false
                    self.apply(addon: addon)
                    self.presentAlert(title: "Failed to update private browsing access", message: "\(error)")
                }
            }
        }
    }
    
    @objc private func enableSwitchChanged(_ sender: UISwitch) {
        let desiredState = sender.isOn
        
        Task { [weak self] in
            guard let self, let addon = self.addon else {
                await MainActor.run {
                    sender.setOn(!desiredState, animated: true)
                }
                return
            }
            
            await MainActor.run {
                self.isUpdatingAddon = true
                self.tableView.reloadData()
            }
            
            do {
                let updatedAddon = try await (desiredState
                                              ? AddonsRuntime.shared.enable(addon)
                                              : AddonsRuntime.shared.disable(addon))
                
                await MainActor.run {
                    self.isUpdatingAddon = false
                    self.apply(addon: updatedAddon)
                }
            } catch {
                await MainActor.run {
                    self.isUpdatingAddon = false
                    self.apply(addon: addon)
                    self.presentAlert(title: "Failed to \(desiredState ? "enable" : "disable") add-on", message: "\(error)")
                }
            }
        }
    }
    
    private func reloadAddon() async {
        do {
            let refreshedAddon = try await AddonsRuntime.shared.addon(byID: addonID)
            await MainActor.run {
                guard let refreshedAddon else {
                    self.navigationController?.popViewController(animated: true)
                    return
                }
                
                self.apply(addon: refreshedAddon)
            }
        } catch {
            await MainActor.run {
                self.presentAlert(title: "Failed to reload add-on", message: "\(error)")
            }
        }
    }
    
    private func apply(addon: Addon) {
        self.addon = addon
        title = addon.metaData.name ?? addon.id
        enableSwitch.isOn = addon.metaData.enabled
        enableSwitch.isEnabled = addon.metaData.canToggleEnabledState && !isUpdatingAddon
        privateBrowsingSwitch.isOn = addon.metaData.allowedInPrivateBrowsing
        privateBrowsingSwitch.isEnabled = addon.metaData.incognito != .notAllowed && !isUpdatingAddon
        tableView.reloadData()
    }
    
    private func statusCell() -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.selectionStyle = .none
        cell.textLabel?.numberOfLines = 0
        
        if let statusMessage {
            cell.textLabel?.text = statusMessage.text
            cell.textLabel?.textColor = statusMessage.color
        }
        
        return cell
    }
    
    private func actionCell(for indexPath: IndexPath) -> UITableViewCell {
        guard actionRows.indices.contains(indexPath.row) else {
            return UITableViewCell()
        }
        
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.numberOfLines = 0
        
        switch actionRows[indexPath.row] {
        case .enabled:
            cell.textLabel?.text = "Enabled"
            cell.selectionStyle = .none
            cell.accessoryView = enableSwitch
        case .privateBrowsing:
            cell.textLabel?.text = addon?.metaData.incognito == .notAllowed
            ? "Not Allowed in Private Browsing"
            : "Allow in Private Browsing"
            cell.textLabel?.textColor = addon?.metaData.incognito == .notAllowed ? .secondaryLabel : .label
            cell.selectionStyle = .none
            cell.accessoryView = privateBrowsingSwitch
        case .remove:
            cell.textLabel?.text = "Remove"
            cell.textLabel?.textColor = addon == nil || isUpdatingAddon ? .secondaryLabel : .systemRed
        case .settings, .details, .permissions:
            break
        }
        
        if addon == nil || isUpdatingAddon {
            cell.isUserInteractionEnabled = false
        }
        
        return cell
    }
    
    private func navigationCell(for indexPath: IndexPath) -> UITableViewCell {
        guard navigationRows.indices.contains(indexPath.row) else {
            return UITableViewCell()
        }
        
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.numberOfLines = 0
        cell.textLabel?.textColor = addon == nil || isUpdatingAddon ? .secondaryLabel : view.tintColor
        cell.accessoryType = .disclosureIndicator
        
        switch navigationRows[indexPath.row] {
        case .settings:
            cell.textLabel?.text = "Settings"
        case .details:
            cell.textLabel?.text = "Details"
        case .permissions:
            cell.textLabel?.text = "Permissions"
        case .remove:
            cell.textLabel?.text = "Remove"
            cell.textLabel?.textColor = addon == nil || isUpdatingAddon ? .secondaryLabel : .systemRed
            cell.accessoryType = .none
        case .enabled, .privateBrowsing:
            break
        }
        
        if addon == nil || isUpdatingAddon {
            cell.isUserInteractionEnabled = false
        }
        
        return cell
    }
    
    private func presentRemoveConfirmation() {
        let addonName = addon?.metaData.name ?? addonID
        let alert = UIAlertController(
            title: "Do you want to remove \(addonName)?",
            message: nil,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Remove", style: .destructive) { [weak self] _ in
            self?.removeAddon()
        })
        present(alert, animated: true)
    }
    
    private func removeAddon() {
        Task { [weak self] in
            guard let self, let addon = self.addon else {
                return
            }
            
            await MainActor.run {
                self.isUpdatingAddon = true
                self.tableView.reloadData()
            }
            
            do {
                try await AddonsRuntime.shared.uninstall(addon)
                await MainActor.run {
                    self.navigationController?.popViewController(animated: true)
                }
            } catch {
                await MainActor.run {
                    self.isUpdatingAddon = false
                    self.apply(addon: addon)
                    self.presentAlert(title: "Failed to remove add-on", message: "\(error)")
                }
            }
        }
    }
}

private final class AddonInformationPreferencesViewController: SettingsTableViewController {
    private enum Section {
        case description
        case information
        case links
    }
    
    private struct InformationRow {
        let title: String
        let value: String
        let link: String?
    }
    
    private let addonID: String
    private var addon: Addon?
    private let reviewCountFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()
    private let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    private var visibleSections: [Section] {
        var sections: [Section] = []
        
        if descriptionText != nil {
            sections.append(.description)
        }
        
        if !informationRows.isEmpty {
            sections.append(.information)
        }
        
        if !linkRows.isEmpty {
            sections.append(.links)
        }
        
        return sections
    }
    
    private var descriptionText: String? {
        guard let metaData = addon?.metaData else {
            return nil
        }
        
        let description = metaData.fullDescription ?? metaData.description
        let trimmed = description?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }
    
    private var informationRows: [InformationRow] {
        guard let addon else {
            return []
        }
        
        let metaData = addon.metaData
        var rows: [InformationRow] = []
        
        if let creatorName = metaData.creatorName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !creatorName.isEmpty {
            rows.append(InformationRow(title: "Author", value: creatorName, link: validatedURLString(metaData.creatorURL)))
        }
        
        rows.append(InformationRow(title: "Version", value: metaData.version, link: nil))
        
        if let updateDate = formattedUpdateDate(metaData.updateDate) {
            rows.append(InformationRow(title: "Last updated", value: updateDate, link: nil))
        }
        
        if let ratingText = formattedRating(metaData) {
            rows.append(InformationRow(title: "Rating", value: ratingText, link: validatedURLString(metaData.reviewURL)))
        }
        
        return rows
    }
    
    private var linkRows: [InformationRow] {
        guard let metaData = addon?.metaData else {
            return []
        }
        
        var rows: [InformationRow] = []
        
        if let homepageURL = validatedURLString(metaData.homepageURL) {
            rows.append(InformationRow(title: "Homepage", value: homepageURL, link: homepageURL))
        }
        
        if let listingURL = validatedURLString(metaData.amoListingURL) {
            rows.append(InformationRow(title: "More about this extension", value: listingURL, link: listingURL))
        }
        
        return rows
    }
    
    init(addonID: String) {
        self.addonID = addonID
        super.init(style: .insetGrouped)
        title = "Details"
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Task { [weak self] in
            await self?.reloadAddon()
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        visibleSections.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard visibleSections.indices.contains(section) else {
            return 0
        }
        
        switch visibleSections[section] {
        case .description:
            return descriptionText == nil ? 0 : 1
        case .information:
            return informationRows.count
        case .links:
            return linkRows.count
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard visibleSections.indices.contains(section) else {
            return nil
        }
        
        switch visibleSections[section] {
        case .description:
            return nil
        case .information:
            return informationRows.isEmpty ? nil : "Information"
        case .links:
            return linkRows.isEmpty ? nil : "Links"
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard visibleSections.indices.contains(indexPath.section) else {
            return UITableViewCell()
        }
        
        switch visibleSections[indexPath.section] {
        case .description:
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.selectionStyle = .none
            cell.textLabel?.numberOfLines = 0
            cell.textLabel?.text = descriptionText
            return cell
        case .information:
            guard informationRows.indices.contains(indexPath.row) else {
                return UITableViewCell()
            }
            let row = informationRows[indexPath.row]
            let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
            cell.textLabel?.text = row.title
            cell.detailTextLabel?.text = row.value
            cell.detailTextLabel?.textColor = row.link == nil ? .secondaryLabel : view.tintColor
            cell.accessoryType = row.link == nil ? .none : .disclosureIndicator
            return cell
        case .links:
            guard linkRows.indices.contains(indexPath.row) else {
                return UITableViewCell()
            }
            let row = linkRows[indexPath.row]
            let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
            cell.textLabel?.text = row.title
            cell.detailTextLabel?.text = row.value
            cell.detailTextLabel?.numberOfLines = 0
            cell.detailTextLabel?.textColor = .secondaryLabel
            cell.accessoryType = .disclosureIndicator
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer { tableView.deselectRow(at: indexPath, animated: true) }
        
        guard visibleSections.indices.contains(indexPath.section) else {
            return
        }
        
        switch visibleSections[indexPath.section] {
        case .description:
            return
        case .information:
            guard informationRows.indices.contains(indexPath.row),
                  let url = informationRows[indexPath.row].link else {
                return
            }
            openLinkInBrowser(url)
        case .links:
            guard linkRows.indices.contains(indexPath.row),
                  let url = linkRows[indexPath.row].link else {
                return
            }
            openLinkInBrowser(url)
        }
    }
    
    private func reloadAddon() async {
        do {
            let refreshedAddon = try await AddonsRuntime.shared.addon(byID: addonID)
            await MainActor.run {
                guard let refreshedAddon else {
                    self.navigationController?.popViewController(animated: true)
                    return
                }
                
                self.addon = refreshedAddon
                self.title = refreshedAddon.metaData.name ?? refreshedAddon.id
                self.tableView.reloadData()
            }
        } catch {
            await MainActor.run {
                self.presentAlert(title: "Failed to reload add-on", message: "\(error)")
            }
        }
    }
    
    private func validatedURLString(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty,
              URL(string: value) != nil else {
            return nil
        }
        return value
    }
    
    private func formattedUpdateDate(_ value: String?) -> String? {
        guard let value,
              let date = ISO8601DateFormatter().date(from: value) else {
            return nil
        }
        
        return displayDateFormatter.string(from: date)
    }
    
    private func formattedRating(_ metaData: AddonMetaData) -> String? {
        guard let averageRating = metaData.averageRating else {
            return nil
        }
        
        let roundedRating = String(format: "%.2f", averageRating)
        if let reviewCount = metaData.reviewCount {
            let reviewText = reviewCountFormatter.string(from: NSNumber(value: reviewCount)) ?? "\(reviewCount)"
            return "\(roundedRating) out of 5 • Reviews: \(reviewText)"
        }
        
        return "\(roundedRating) out of 5"
    }
}

private final class AddonPermissionsPreferencesViewController: SettingsTableViewController {
    private struct SectionModel {
        let title: String?
        let rows: [Row]
    }
    
    private enum Row {
        case message(String)
        case toggle(title: String, subtitle: String?, isOn: Bool, isEnabled: Bool, kind: ToggleKind)
        case warning(String)
    }
    
    private enum ToggleKind {
        case allSites([String])
        case optionalPermission(String)
        case origin(String)
        case optionalDataCollection(String)
    }
    
    private let addonID: String
    private var addon: Addon?
    private var isUpdatingPermissions = false
    
    private var sectionModels: [SectionModel] {
        guard let addon else {
            return []
        }
        
        let metaData = addon.metaData
        let requiredPermissions = AddonPermissionSupport.localizePermissions(metaData.requiredPermissions + metaData.requiredOrigins)
        let optionalPermissions = AddonPermissionSupport.localizeOptionalPermissions(
            metaData.optionalPermissions,
            grantedPermissions: metaData.grantedOptionalPermissions
        )
        
        var combinedOptionalOrigins: [String] = []
        for origin in metaData.optionalOrigins + metaData.grantedOptionalOrigins where !combinedOptionalOrigins.contains(origin) {
            combinedOptionalOrigins.append(origin)
        }
        
        let allSiteOrigins = AddonPermissionSupport.allSiteOriginPermissions(combinedOptionalOrigins)
        let allSitesEnabled = metaData.grantedOptionalOrigins.contains(where: { allSiteOrigins.contains($0) })
        let optionalOrigins = AddonPermissionSupport.localizeOptionalOrigins(
            combinedOptionalOrigins,
            grantedOrigins: metaData.grantedOptionalOrigins
        ).filter { !allSiteOrigins.contains($0.name) }
        let optionalDataCollectionPermissions = AddonPermissionSupport.localizeOptionalDataCollectionPermissions(
            metaData.optionalDataCollectionPermissions,
            grantedPermissions: metaData.grantedOptionalDataCollectionPermissions
        )
        
        var sections: [SectionModel] = []
        
        if requiredPermissions.isEmpty,
           optionalPermissions.isEmpty,
           optionalOrigins.isEmpty,
           metaData.requiredDataCollectionPermissions.isEmpty,
           optionalDataCollectionPermissions.isEmpty {
            sections.append(
                SectionModel(
                    title: nil,
                    rows: [.message(AddonPermissionSupport.noPermissionsRequiredDescription)]
                )
            )
            return sections
        }
        
        if !requiredPermissions.isEmpty {
            sections.append(
                SectionModel(
                    title: "Required Permissions",
                    rows: requiredPermissions.map(Row.message)
                )
            )
        }
        
        var optionalRows: [Row] = []
        if !allSiteOrigins.isEmpty {
            optionalRows.append(
                .toggle(
                    title: AddonPermissionSupport.allowForAllSitesTitle,
                    subtitle: AddonPermissionSupport.allowForAllSitesSubtitle,
                    isOn: allSitesEnabled,
                    isEnabled: !isUpdatingPermissions,
                    kind: .allSites(allSiteOrigins)
                )
            )
        }
        
        optionalPermissions.forEach { permission in
            optionalRows.append(
                .toggle(
                    title: permission.localizedName,
                    subtitle: nil,
                    isOn: permission.granted,
                    isEnabled: !isUpdatingPermissions,
                    kind: .optionalPermission(permission.name)
                )
            )
            
            if permission.name == "userScripts" {
                optionalRows.append(.warning(AddonPermissionSupport.userScriptsWarning))
            }
        }
        
        optionalOrigins.forEach { permission in
            optionalRows.append(
                .toggle(
                    title: permission.localizedName,
                    subtitle: nil,
                    isOn: permission.granted,
                    isEnabled: !allSitesEnabled && !isUpdatingPermissions,
                    kind: .origin(permission.name)
                )
            )
        }
        
        if !optionalRows.isEmpty {
            sections.append(SectionModel(title: "Optional Permissions", rows: optionalRows))
        }
        
        if let requiredDataCollectionDescription = AddonPermissionSupport.requiredDataCollectionDescription(for: metaData.requiredDataCollectionPermissions) {
            sections.append(
                SectionModel(
                    title: "Required Data Collection",
                    rows: [.message(requiredDataCollectionDescription)]
                )
            )
        }
        
        if !optionalDataCollectionPermissions.isEmpty {
            sections.append(
                SectionModel(
                    title: "Optional Data Collection",
                    rows: optionalDataCollectionPermissions.map {
                        .toggle(
                            title: $0.localizedName,
                            subtitle: nil,
                            isOn: $0.granted,
                            isEnabled: !isUpdatingPermissions,
                            kind: .optionalDataCollection($0.name)
                        )
                    }
                )
            )
        }
        
        return sections
    }
    
    init(addonID: String) {
        self.addonID = addonID
        super.init(style: .insetGrouped)
        title = "Permissions"
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Task { [weak self] in
            await self?.reloadAddon()
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        sectionModels.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard sectionModels.indices.contains(section) else {
            return 0
        }
        
        return sectionModels[section].rows.count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard sectionModels.indices.contains(section) else {
            return nil
        }
        
        return sectionModels[section].title
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard sectionModels.indices.contains(indexPath.section),
              sectionModels[indexPath.section].rows.indices.contains(indexPath.row) else {
            return UITableViewCell()
        }
        
        switch sectionModels[indexPath.section].rows[indexPath.row] {
        case .message(let text):
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.selectionStyle = .none
            cell.textLabel?.text = text
            cell.textLabel?.numberOfLines = 0
            return cell
        case .toggle(let title, let subtitle, let isOn, let isEnabled, _):
            let cell = UITableViewCell(style: subtitle == nil ? .default : .subtitle, reuseIdentifier: nil)
            let toggle = UISwitch()
            toggle.isOn = isOn
            toggle.isEnabled = isEnabled
            toggle.tag = indexPath.section * 1000 + indexPath.row
            toggle.addTarget(self, action: #selector(permissionSwitchChanged(_:)), for: .valueChanged)
            cell.selectionStyle = .none
            cell.textLabel?.text = title
            cell.textLabel?.numberOfLines = 0
            cell.detailTextLabel?.text = subtitle
            cell.detailTextLabel?.numberOfLines = 0
            cell.detailTextLabel?.textColor = .secondaryLabel
            cell.accessoryView = toggle
            return cell
        case .warning(let text):
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.selectionStyle = .none
            cell.textLabel?.text = text
            cell.textLabel?.numberOfLines = 0
            cell.textLabel?.textColor = .secondaryLabel
            return cell
        }
    }
    
    @objc private func permissionSwitchChanged(_ sender: UISwitch) {
        let section = sender.tag / 1000
        let row = sender.tag % 1000
        
        guard sectionModels.indices.contains(section),
              sectionModels[section].rows.indices.contains(row),
              case let .toggle(_, _, isOn, _, kind) = sectionModels[section].rows[row],
              let addon else {
            return
        }
        
        let desiredState = sender.isOn
        if desiredState == isOn {
            return
        }
        
        let request: AddonPermissionChangeRequest
        switch kind {
        case .allSites(let origins):
            request = AddonPermissionChangeRequest(origins: origins)
        case .optionalPermission(let permission):
            request = AddonPermissionChangeRequest(permissions: [permission])
        case .origin(let origin):
            request = AddonPermissionChangeRequest(origins: [origin])
        case .optionalDataCollection(let permission):
            request = AddonPermissionChangeRequest(dataCollectionPermissions: [permission])
        }
        
        Task { [weak self] in
            guard let self else {
                return
            }
            
            await MainActor.run {
                self.isUpdatingPermissions = true
                self.tableView.reloadData()
            }
            
            do {
                let updatedAddon = try await (desiredState
                                              ? AddonsRuntime.shared.addOptionalPermissions(request, to: addon)
                                              : AddonsRuntime.shared.removeOptionalPermissions(request, from: addon))
                
                await MainActor.run {
                    self.isUpdatingPermissions = false
                    self.addon = updatedAddon
                    self.title = updatedAddon.metaData.name ?? updatedAddon.id
                    self.tableView.reloadData()
                }
            } catch {
                await MainActor.run {
                    self.isUpdatingPermissions = false
                    self.addon = addon
                    self.tableView.reloadData()
                    self.presentAlert(title: "Failed to update permissions", message: "\(error)")
                }
            }
        }
    }
    
    private func reloadAddon() async {
        do {
            let refreshedAddon = try await AddonsRuntime.shared.addon(byID: addonID)
            await MainActor.run {
                guard let refreshedAddon else {
                    self.navigationController?.popViewController(animated: true)
                    return
                }
                
                self.addon = refreshedAddon
                self.title = refreshedAddon.metaData.name ?? refreshedAddon.id
                self.tableView.reloadData()
            }
        } catch {
            await MainActor.run {
                self.presentAlert(title: "Failed to reload add-on", message: "\(error)")
            }
        }
    }
}

private extension UIViewController {
    func openLinkInBrowser(_ urlString: String) {
        let trimmedURLString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURLString.isEmpty,
              let browserViewController = resolvedBrowserViewController() else {
            return
        }
        
        let openTab: () -> Void = {
            browserViewController.loadViewIfNeeded()
            let insertIndex = browserViewController.tabManager.regularTabs.count
            let tabIndex = browserViewController.createTab(selecting: true, at: insertIndex, isPrivate: false)
            guard browserViewController.tabManager.regularTabs.indices.contains(tabIndex) else {
                return
            }
            
            let tab = browserViewController.tabManager.regularTabs[tabIndex]
            browserViewController.tabManager.browse(to: trimmedURLString, in: tab)
            browserViewController.refreshAddressBar()
        }
        
        if navigationController?.presentingViewController is BrowserViewController {
            navigationController?.dismiss(animated: true, completion: openTab)
        } else {
            openTab()
        }
    }
    
    func resolvedBrowserViewController() -> BrowserViewController? {
        if let splitViewController = splitViewController as? BrowserSplitViewController {
            return splitViewController.contentBrowserViewController
        }
        
        if let browserViewController = navigationController?.presentingViewController as? BrowserViewController {
            return browserViewController
        }
        
        return view.window?.rootViewController.flatMap { resolvedBrowserViewController(from: $0) }
    }
    
    func resolvedBrowserViewController(from controller: UIViewController) -> BrowserViewController? {
        if let browserViewController = controller as? BrowserViewController {
            return browserViewController
        }
        
        if let navigationController = controller as? UINavigationController {
            return navigationController.viewControllers.compactMap { resolvedBrowserViewController(from: $0) }.first
        }
        
        if let tabBarController = controller as? UITabBarController,
           let viewControllers = tabBarController.viewControllers {
            return viewControllers.compactMap { resolvedBrowserViewController(from: $0) }.first
        }
        
        if let splitViewController = controller as? BrowserSplitViewController {
            return splitViewController.contentBrowserViewController
        }
        
        if let presentedViewController = controller.presentedViewController,
           let browserViewController = resolvedBrowserViewController(from: presentedViewController) {
            return browserViewController
        }
        
        return controller.children.compactMap { resolvedBrowserViewController(from: $0) }.first
    }
}
