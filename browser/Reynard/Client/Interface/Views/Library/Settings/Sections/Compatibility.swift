//
//  Compatibility.swift
//  Reynard
//
//  Created by Minh Ton on 11/4/26.
//

import UIKit

private final class AttributedFooterView: UITableViewHeaderFooterView {
    private let textView = UITextView()
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.isUserInteractionEnabled = true
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 6, left: 16, bottom: 18, right: 16)
        textView.textContainer.lineFragmentPadding = 0
        textView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: contentView.topAnchor),
            textView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(with attributedText: NSAttributedString) {
        textView.attributedText = attributedText
    }
}

final class UserAgentOverrideViewController: UITableViewController {
    private enum Section: Int, CaseIterable {
        case userList
        case defaultList
    }
    
    private static let footerReuseID = "userListFooter"
    
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
        tableView.sectionFooterHeight = UITableView.automaticDimension
        tableView.estimatedSectionFooterHeight = 100
        tableView.register(AttributedFooterView.self, forHeaderFooterViewReuseIdentifier: Self.footerReuseID)
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .userList: return domains.count + 1
        case .defaultList: return 1
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
        case .defaultList:
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = "Default Overrides"
            cell.accessoryType = .disclosureIndicator
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
        switch Section(rawValue: indexPath.section) {
        case .userList where indexPath.row == domains.count:
            showAddDomainAlert()
        case .defaultList:
            navigationController?.pushViewController(DefaultSiteListViewController(), animated: true)
        default:
            break
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .userList: return nil
        case .defaultList: return "To improve compatibility, the browser will use a customized user agent for sites on this list. This list updates automatically as you use the browser."
        case nil: return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        guard Section(rawValue: section) == .userList else { return nil }
        let footer = tableView.dequeueReusableHeaderFooterView(withIdentifier: Self.footerReuseID) as! AttributedFooterView
        footer.configure(with: makeUserListFooterAttributedString())
        return footer
    }
    
    private func makeUserListFooterAttributedString() -> NSAttributedString {
        let linkText = "creating an issue on GitHub"
        let linkURL = URL(string: "https://github.com/minh-ton/reynard-browser/issues")!
        let fullText = "Navigations to these websites will use the Firefox for Android user agent. As a result, these websites may identify your device as an Android device.\n\nIf adding websites to this list resolves issues, consider sharing your list by \(linkText) so others can experience these sites without problems."
        
        let font = UIFont.preferredFont(forTextStyle: .footnote)
        let baseAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.secondaryLabel,
        ]
        let attributed = NSMutableAttributedString(string: fullText, attributes: baseAttrs)
        if let range = fullText.range(of: linkText) {
            attributed.addAttribute(.link, value: linkURL, range: NSRange(range, in: fullText))
        }
        return attributed
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

final class DefaultSiteListViewController: UITableViewController {
    private var sites: [String] = []
    
    init() {
        super.init(style: .insetGrouped)
        title = "Default Overrides"
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sites = UAOverride.shared.defaultSites
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int { 1 }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sites.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = sites[indexPath.row]
        cell.selectionStyle = .none
        return cell
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
