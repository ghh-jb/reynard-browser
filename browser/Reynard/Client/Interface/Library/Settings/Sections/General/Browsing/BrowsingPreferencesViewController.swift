//
//  BrowsingPreferencesViewController.swift
//  Reynard
//
//  Created by Minh Ton on 15/5/26.
//

import UIKit

final class BrowsingPreferencesViewController: SettingsTableViewController {
    private enum Section: CaseIterable {
        case media
        case desktopWebsite
        
        var text: SettingsSectionText {
            switch self {
            case .media:
                return SettingsSectionText(headerTitle: "Media")
            case .desktopWebsite:
                return SettingsSectionText(headerTitle: "Request Desktop Website On")
            }
        }
    }
    
    private enum MediaRow: CaseIterable {
        case autoplay
    }
    
    private enum DesktopWebsiteRow: CaseIterable {
        case allWebsites
    }
    
    private let requestDesktopWebsiteSwitch = UISwitch()
    
    init() {
        super.init(style: .insetGrouped)
        title = "Browsing"
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureSwitch()
        refreshDisplayedState()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshDisplayedState()
        tableView.reloadData()
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard Section.allCases.indices.contains(section) else {
            return 0
        }
        
        switch Section.allCases[section] {
        case .media:
            return MediaRow.allCases.count
        case .desktopWebsite:
            return DesktopWebsiteRow.allCases.count
        }
    }
    
    override func sectionText(for section: Int) -> SettingsSectionText {
        guard Section.allCases.indices.contains(section) else {
            return SettingsSectionText()
        }
        return Section.allCases[section].text
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard Section.allCases.indices.contains(indexPath.section) else {
            return UITableViewCell()
        }
        
        switch Section.allCases[indexPath.section] {
        case .media:
            guard MediaRow.allCases.indices.contains(indexPath.row) else {
                return UITableViewCell()
            }
            let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
            cell.textLabel?.text = "Autoplay"
            cell.detailTextLabel?.text = SiteSettingsUtils.actionTitle(
                for: SiteSettingsUtils.defaultAction(for: .autoplay),
                permission: .autoplay
            )
            cell.accessoryType = .disclosureIndicator
            return cell
        case .desktopWebsite:
            guard DesktopWebsiteRow.allCases.indices.contains(indexPath.row) else {
                return UITableViewCell()
            }
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.selectionStyle = .none
            cell.textLabel?.text = "All Website"
            cell.accessoryView = requestDesktopWebsiteSwitch
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer { tableView.deselectRow(at: indexPath, animated: true) }
        guard Section.allCases.indices.contains(indexPath.section) else {
            return
        }
        
        switch Section.allCases[indexPath.section] {
        case .media:
            guard MediaRow.allCases.indices.contains(indexPath.row) else {
                return
            }
            navigationController?.pushViewController(
                SitePermissionDetailsViewController(permission: .autoplay, title: "Autoplay"),
                animated: true
            )
        case .desktopWebsite:
            return
        }
    }
    
    private func configureSwitch() {
        requestDesktopWebsiteSwitch.addTarget(self, action: #selector(requestDesktopWebsiteSwitchDidChange(_:)), for: .valueChanged)
    }
    
    private func refreshDisplayedState() {
        requestDesktopWebsiteSwitch.isOn = Prefs.BrowsingSettings.requestDesktopWebsite
    }
    
    @objc private func requestDesktopWebsiteSwitchDidChange(_ sender: UISwitch) {
        Prefs.BrowsingSettings.requestDesktopWebsite = sender.isOn
    }
}
