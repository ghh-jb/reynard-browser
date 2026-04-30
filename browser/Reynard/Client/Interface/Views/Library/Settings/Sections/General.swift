//
//  General.swift
//  Reynard
//
//  Created by Minh Ton on 30/4/26.
//

import GeckoView
import UIKit

final class AddonsSettingsViewController: SettingsTableViewController {
    private enum Section: Int, CaseIterable {
        case installed
        case more
    }
    
    private static let sharedIconCache = NSCache<NSString, UIImage>()
    private static var hasLoadedInstalledAddons = false
    
    private let iconLoadingQueue = DispatchQueue(label: "me.minh-ton.reynard.settings.addons.icons", qos: .utility)
    private var iconLoadingIDs = Set<String>()
    private var addons: [Addon] = []
    private var isLoadingAddons = false
    
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
            return 1
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
            cell.textLabel?.text = "Discover Add-ons..."
            cell.textLabel?.textColor = view.tintColor
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
                AddonSettingsDetailViewController(addonID: addon.id),
                animated: true
            )
        case .more:
            openLinkInBrowser("https://addons.mozilla.org/android/")
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
        addons = AddonsRuntimeController.shared.installedAddons
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
            refreshedAddons = try await AddonsRuntimeController.shared.list()
        } catch {
            refreshedAddons = AddonsRuntimeController.shared.installedAddons
        }
        
        await MainActor.run {
            Self.hasLoadedInstalledAddons = true
            self.addons = refreshedAddons
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

final class AddonSettingsDetailViewController: SettingsTableViewController {
    private enum Section: Int, CaseIterable {
        case actions
        case information
    }
    
    private enum ActionRow: Int, CaseIterable {
        case enabled
        case options
        case remove
    }
    
    private struct InformationRow {
        let title: String
        let value: String
        let style: UITableViewCell.CellStyle
    }
    
    private let addonID: String
    private let enableSwitch = UISwitch()
    private var addon: Addon?
    
    private var actionRows: [ActionRow] {
        var rows: [ActionRow] = [.enabled]
        if optionsPageURL != nil {
            rows.append(.options)
        }
        rows.append(.remove)
        return rows
    }
    
    private var informationRows: [InformationRow] {
        guard let metaData = addon?.metaData else {
            return []
        }
        
        var rows: [InformationRow] = []
        
        appendValueRow(title: "Name", value: metaData.name, style: .value1, to: &rows)
        appendValueRow(title: "Version", value: metaData.version, style: .value1, to: &rows)
        appendValueRow(title: "Description", value: metaData.description, style: .subtitle, to: &rows)
        appendListRow(title: "Required Permissions", values: metaData.requiredPermissions, to: &rows)
        appendListRow(title: "Required Origins", values: metaData.requiredOrigins, to: &rows)
        appendListRow(title: "Optional Permissions", values: metaData.optionalPermissions, to: &rows)
        appendListRow(title: "Optional Origins", values: metaData.optionalOrigins, to: &rows)
        appendListRow(title: "Granted Optional Permissions", values: metaData.grantedOptionalPermissions, to: &rows)
        appendListRow(title: "Granted Optional Origins", values: metaData.grantedOptionalOrigins, to: &rows)
        
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
        enableSwitch.addTarget(self, action: #selector(enableSwitchChanged(_:)), for: .valueChanged)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Task { [weak self] in
            await self?.reloadAddon()
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .actions:
            return actionRows.count
        case .information:
            return informationRows.count
        case nil:
            return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section) {
        case .actions:
            return actionCell(for: indexPath)
        case .information:
            return informationCell(for: indexPath)
        case nil:
            return UITableViewCell()
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer { tableView.deselectRow(at: indexPath, animated: true) }
        guard Section(rawValue: indexPath.section) == .actions,
              actionRows.indices.contains(indexPath.row) else {
            return
        }
        
        let row = actionRows[indexPath.row]
        
        switch row {
        case .enabled:
            return
        case .options:
            guard let optionsPageURL else {
                return
            }
            openLinkInBrowser(optionsPageURL)
        case .remove:
            presentRemoveConfirmation()
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .actions:
            return nil
        case .information:
            return informationRows.isEmpty ? nil : "Information"
        case nil:
            return nil
        }
    }
    
    @objc private func enableSwitchChanged(_ sender: UISwitch) {
        let desiredState = sender.isOn
        sender.isEnabled = false
        
        Task { [weak self] in
            guard let self, let addon = self.addon else {
                await MainActor.run {
                    sender.setOn(!desiredState, animated: true)
                    sender.isEnabled = true
                }
                return
            }
            
            do {
                let updatedAddon = try await (desiredState
                                              ? AddonsRuntimeController.shared.enable(addon)
                                              : AddonsRuntimeController.shared.disable(addon))
                
                await MainActor.run {
                    self.apply(addon: updatedAddon)
                    sender.isEnabled = true
                }
            } catch {
                await MainActor.run {
                    sender.setOn(!desiredState, animated: true)
                    sender.isEnabled = true
                    self.presentAlert(title: "Failed to \(desiredState ? "enable" : "disable") add-on", message: "\(error)")
                }
            }
        }
    }
    
    private func reloadAddon() async {
        do {
            let refreshedAddon = try await AddonsRuntimeController.shared.addon(byID: addonID)
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
        tableView.reloadData()
    }
    
    private func actionCell(for indexPath: IndexPath) -> UITableViewCell {
        guard actionRows.indices.contains(indexPath.row) else {
            return UITableViewCell()
        }
        
        let row = actionRows[indexPath.row]
        
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        
        switch row {
        case .enabled:
            cell.textLabel?.text = "Enabled"
            cell.selectionStyle = .none
            cell.accessoryView = enableSwitch
        case .options:
            cell.textLabel?.text = "Add-on Settings"
            cell.textLabel?.textColor = view.tintColor
        case .remove:
            cell.textLabel?.text = "Remove Add-on..."
            cell.textLabel?.textColor = .systemRed
        }
        
        return cell
    }
    
    private func informationCell(for indexPath: IndexPath) -> UITableViewCell {
        guard informationRows.indices.contains(indexPath.row) else {
            return UITableViewCell()
        }
        
        let row = informationRows[indexPath.row]
        let cell = UITableViewCell(style: row.style, reuseIdentifier: nil)
        cell.selectionStyle = .none
        cell.textLabel?.text = row.title
        cell.textLabel?.numberOfLines = 0
        cell.detailTextLabel?.text = row.value
        cell.detailTextLabel?.numberOfLines = 0
        cell.detailTextLabel?.textColor = .secondaryLabel
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
            
            do {
                try await AddonsRuntimeController.shared.uninstall(addon)
                await MainActor.run {
                    self.navigationController?.popViewController(animated: true)
                }
            } catch {
                await MainActor.run {
                    self.presentAlert(title: "Failed to remove add-on", message: "\(error)")
                }
            }
        }
    }
    
    private func appendValueRow(title: String, value: String?, style: UITableViewCell.CellStyle, to rows: inout [InformationRow]) {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return
        }
        
        rows.append(InformationRow(title: title, value: value, style: style))
    }
    
    private func appendListRow(title: String, values: [String], to rows: inout [InformationRow]) {
        let filteredValues = values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        guard !filteredValues.isEmpty else {
            return
        }
        
        rows.append(InformationRow(title: title, value: filteredValues.joined(separator: "\n"), style: .subtitle))
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
            let insertIndex = browserViewController.tabManager.tabs.count
            let tabIndex = browserViewController.createTab(selecting: true, at: insertIndex)
            guard browserViewController.tabManager.tabs.indices.contains(tabIndex) else {
                return
            }
            
            let tab = browserViewController.tabManager.tabs[tabIndex]
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
