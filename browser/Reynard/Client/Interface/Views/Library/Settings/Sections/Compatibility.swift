//
//  Compatibility.swift
//  Reynard
//
//  Created by Minh Ton on 11/4/26.
//

import UIKit

final class UserAgentOverrideViewController: UITableViewController {
    private var domains: [String] = []
    private let preferences = BrowserPreferences.shared

    init() {
        super.init(style: .insetGrouped)
        title = "User Agent Override"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        domains = preferences.androidUserAgentDomains
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 2 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? domains.count : 2
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 1 {
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            if indexPath.row == 0 {
                cell.textLabel?.text = "Add Website..."
                cell.textLabel?.textColor = tableView.tintColor
            } else {
                cell.textLabel?.text = "Reset to Default"
                cell.textLabel?.textColor = .systemRed
            }
            return cell
        }
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = domains[indexPath.row]
        cell.selectionStyle = .default
        return cell
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        indexPath.section == 0
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete, indexPath.section == 0 else { return }
        domains.remove(at: indexPath.row)
        preferences.androidUserAgentDomains = domains
        tableView.deleteRows(at: [indexPath], with: .automatic)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section == 1 else { return }
        if indexPath.row == 0 {
            showAddDomainAlert()
        } else {
            resetToDefault()
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard section == 0 else { return nil }
        return "Navigations to these websites will use the Firefox for Android User Agent, which may improve compatibility. However, these websites may identify your device as an Android device."
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

    private func resetToDefault() {
        domains = BrowserPreferences.defaultAndroidUserAgentDomains
        preferences.androidUserAgentDomains = domains
        tableView.reloadSections(IndexSet(integer: 0), with: .automatic)
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
