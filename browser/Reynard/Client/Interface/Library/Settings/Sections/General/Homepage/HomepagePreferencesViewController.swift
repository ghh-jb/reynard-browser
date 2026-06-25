//
//  HomepagePreferencesViewController.swift
//  Reynard
//
//  Created by Minh Ton on 25/6/26.
//

import UIKit

final class HomepagePreferencesViewController: SettingsTableViewController {
    private enum Section: CaseIterable {
        case includeOnHomepage
        
        var text: SettingsSectionText {
            switch self {
            case .includeOnHomepage:
                return SettingsSectionText(
                    headerTitle: "Show on Homepage",
                    footerTitle: "Choose what to show on the homepage."
                )
            }
        }
    }
    
    private enum Row: CaseIterable {
        case favorites
        case frequentlyVisited
        case recentlyClosedTabs
        
        var title: String {
            return preference.title
        }
        
        var isEnabled: Bool {
            return preference.isEnabled
        }
        
        var preference: HomepageSectionPreferencesViewController.Preference {
            switch self {
            case .favorites:
                return .favorites
            case .frequentlyVisited:
                return .frequentlyVisited
            case .recentlyClosedTabs:
                return .recentlyClosedTabs
            }
        }
    }
    
    init() {
        super.init(style: .insetGrouped)
        title = "Homepage"
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard Section.allCases.indices.contains(section) else {
            return 0
        }
        
        return Row.allCases.count
    }
    
    override func sectionText(for section: Int) -> SettingsSectionText {
        guard Section.allCases.indices.contains(section) else {
            return SettingsSectionText()
        }
        
        return Section.allCases[section].text
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard Section.allCases.indices.contains(indexPath.section),
              Row.allCases.indices.contains(indexPath.row) else {
            return UITableViewCell()
        }
        
        let row = Row.allCases[indexPath.row]
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.text = row.title
        cell.detailTextLabel?.text = row.isEnabled ? "On" : "Off"
        cell.accessoryType = .disclosureIndicator
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer { tableView.deselectRow(at: indexPath, animated: true) }
        guard Section.allCases.indices.contains(indexPath.section),
              Row.allCases.indices.contains(indexPath.row) else {
            return
        }
        
        let viewController = HomepageSectionPreferencesViewController(
            preference: Row.allCases[indexPath.row].preference
        )
        navigationController?.pushViewController(viewController, animated: true)
    }
}
