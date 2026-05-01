//
//  Compatibility.swift
//  Reynard
//
//  Created by Minh Ton on 11/4/26.
//

import UIKit

final class UserAgentOverrideViewController: UITableViewController {
    private enum Section: Int, CaseIterable {
        case userList
    }
    
    private var domains: [String] = []
    private let preferences = BrowserPreferences.shared
    
    init() {
        super.init(style: .insetGrouped)
        title = "User Agent Overrides"
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        domains = preferences.androidUserAgentDomains
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .userList: return domains.count + 1
        case nil: return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section) {
        case .userList:
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            if indexPath.row < domains.count {
                cell.textLabel?.text = domains[indexPath.row]
                cell.selectionStyle = .default
            } else {
                cell.textLabel?.text = "Add Website..."
                cell.textLabel?.textColor = tableView.tintColor
            }
            return cell
        case nil:
            return UITableViewCell()
        }
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        indexPath.section == Section.userList.rawValue && indexPath.row < domains.count
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete,
              indexPath.section == Section.userList.rawValue,
              indexPath.row < domains.count else { return }
        domains.remove(at: indexPath.row)
        preferences.androidUserAgentDomains = domains
        tableView.deleteRows(at: [indexPath], with: .automatic)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if Section(rawValue: indexPath.section) == .userList, indexPath.row == domains.count {
            showAddDomainAlert()
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard Section(rawValue: section) == .userList else {
            return nil
        }
        
        return "Navigations to these websites will use the browser's compatibility user agent. Depending on your Request Desktop Website setting, these websites may identify your device as either an Android device or a desktop Linux device."
    }
    
    private func showAddDomainAlert() {
        let alert = UIAlertController(title: "Add Website", message: nil, preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "e.g. youtube.com"
            field.autocorrectionType = .no
            field.autocapitalizationType = .none
            field.keyboardType = .URL
            field.clearButtonMode = .whileEditing
        }
        let addAction = UIAlertAction(title: "Add", style: .default) { [weak self, weak alert] _ in
            guard let text = alert?.textFields?.first?.text else { return }
            self?.insertDomain(text)
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(addAction)
        present(alert, animated: true)
    }
    
    private func insertDomain(_ domain: String) {
        let normalised = domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalised.isEmpty, !domains.contains(normalised) else { return }
        domains.append(normalised)
        domains.sort()
        preferences.androidUserAgentDomains = domains
        tableView.reloadData()
    }
}

extension SettingsRootViewController {
    @objc func androidUASwitchChanged() {
        let nowOn = androidUASwitch.isOn
        preferences.useAndroidUserAgent = nowOn
        guard let section = visibleSections.firstIndex(of: .compatibility) else { return }
        let overrideRowIndexPath = IndexPath(row: 1, section: section)
        UIView.performWithoutAnimation {
            tableView.beginUpdates()
            if nowOn {
                tableView.deleteRows(at: [overrideRowIndexPath], with: .none)
            } else {
                tableView.insertRows(at: [overrideRowIndexPath], with: .none)
            }
            tableView.endUpdates()
        }
        if let footer = tableView.footerView(forSection: section) {
            footer.textLabel?.text = tableView(tableView, titleForFooterInSection: section)
            footer.sizeToFit()
        }
    }
}
