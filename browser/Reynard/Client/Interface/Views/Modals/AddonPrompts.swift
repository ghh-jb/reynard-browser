//
//  AddonPrompts.swift
//  Reynard
//
//  Created by Minh Ton on 23/5/26.
//

import GeckoView
import UIKit

final class AddonPromptViewController: UITableViewController {
    private enum Section: Int, CaseIterable {
        case message
        case permissions
        case options
    }
    
    private enum DisplayItem {
        case domainHeader(String)
        case domain(String)
        case showAllSites
        case permission(String)
        case dataCollection(String)
    }
    
    private static let contractedDomainCount = 5
    
    private let prompt: AddonPermissionPrompt
    private let onDecision: (AddonPermissionPromptResponse) -> Void
    private let permissionRows: [String]
    private let domainRows: [String]
    private let dataCollectionDescription: String?
    private var buttonLeadingConstraint: NSLayoutConstraint?
    private var buttonTrailingConstraint: NSLayoutConstraint?
    private var hasResolvedDecision = false
    private let privateBrowsingSwitch = UISwitch()
    private lazy var actionButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = view.tintColor
        button.tintColor = .white
        button.layer.cornerRadius = 25
        button.layer.cornerCurve = .continuous
        button.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        button.setTitle(prompt.kind == .install ? "Add" : "Allow", for: .normal)
        button.addTarget(self, action: #selector(confirmPrompt), for: .touchUpInside)
        return button
    }()
    
    init(prompt: AddonPermissionPrompt, onDecision: @escaping (AddonPermissionPromptResponse) -> Void) {
        self.prompt = prompt
        self.onDecision = onDecision
        let content = Self.promptContent(for: prompt)
        permissionRows = content.permissionRows
        domainRows = content.domainRows
        dataCollectionDescription = content.dataCollectionDescription
        super.init(style: .insetGrouped)
        title = Self.promptTitle(for: prompt)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemGroupedBackground
        navigationItem.largeTitleDisplayMode = .never
        
        if #available(iOS 26.0, *), MakeButtons.hasLiquidGlass {
            navigationItem.rightBarButtonItems = [
                UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(dismissModal))
            ]
            navigationItem.rightBarButtonItems?.first?.tintColor = .label
        } else {
            navigationItem.rightBarButtonItems = [
                UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissModal))
            ]
        }
        
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 88))
        container.addSubview(actionButton)
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        buttonLeadingConstraint = actionButton.leadingAnchor.constraint(equalTo: container.leadingAnchor)
        buttonTrailingConstraint = actionButton.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        NSLayoutConstraint.activate([
            actionButton.topAnchor.constraint(equalTo: container.topAnchor, constant: 24),
            buttonLeadingConstraint!,
            buttonTrailingConstraint!,
            actionButton.heightAnchor.constraint(equalToConstant: 50),
        ])
        
        tableView.tableFooterView = container
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        let rowRect = tableView.rectForRow(at: IndexPath(row: 0, section: Section.message.rawValue))
        guard rowRect.width > 0 else {
            return
        }
        
        buttonLeadingConstraint?.constant = rowRect.minX
        buttonTrailingConstraint?.constant = -(tableView.bounds.width - rowRect.maxX)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        if !hasResolvedDecision,
           isBeingDismissed || navigationController?.isBeingDismissed == true {
            hasResolvedDecision = true
            onDecision(.deny)
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        prompt.kind == .install ? Section.allCases.count : 2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .message:
            return 1
        case .permissions:
            return displayItems.count
        case .options:
            return prompt.kind == .install ? 1 : 0
        case nil:
            return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .permissions:
            guard !displayItems.isEmpty else {
                return nil
            }
            return "Required Permissions"
        case .options:
            return prompt.kind == .install ? "Additional Options" : nil
        case .message, nil:
            return nil
        }
    }
    
    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell")
        ?? UITableViewCell(style: .default, reuseIdentifier: "Cell")
        cell.textLabel?.numberOfLines = 0
        cell.textLabel?.textColor = .label
        cell.selectionStyle = .none
        
        switch Section(rawValue: indexPath.section) {
        case .message:
            cell.textLabel?.font = .preferredFont(forTextStyle: .headline)
            cell.textLabel?.text = promptMessage()
        case .permissions:
            switch displayItems[indexPath.row] {
            case .domainHeader(let value):
                cell.textLabel?.font = .preferredFont(forTextStyle: .body)
                cell.textLabel?.text = value
            case .domain(let value):
                cell.textLabel?.font = .preferredFont(forTextStyle: .body)
                cell.textLabel?.text = value
            case .showAllSites:
                cell.textLabel?.font = .preferredFont(forTextStyle: .body)
                cell.textLabel?.text = "Show All Sites"
                cell.textLabel?.textColor = view.tintColor
                cell.selectionStyle = .default
                cell.accessoryType = .disclosureIndicator
            case .permission(let value):
                cell.textLabel?.font = .preferredFont(forTextStyle: .body)
                cell.textLabel?.text = value
            case .dataCollection(let value):
                cell.textLabel?.font = .preferredFont(forTextStyle: .body)
                cell.textLabel?.text = value
            }
        case .options:
            cell.textLabel?.font = .preferredFont(forTextStyle: .body)
            cell.textLabel?.text = "Allow in Private Browsing"
            cell.accessoryView = privateBrowsingSwitch
        case nil:
            cell.textLabel?.text = nil
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard Section(rawValue: indexPath.section) == .permissions else {
            tableView.deselectRow(at: indexPath, animated: true)
            return
        }
        
        if case .showAllSites = displayItems[indexPath.row] {
            navigationController?.pushViewController(
                AddonPromptSitesViewController(sites: domainRows),
                animated: true
            )
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    @objc private func dismissModal() {
        dismiss(animated: true)
    }
    
    @objc private func confirmPrompt() {
        guard !hasResolvedDecision else {
            return
        }
        
        hasResolvedDecision = true
        onDecision(
            AddonPermissionPromptResponse(
                allow: true,
                privateBrowsingAllowed: prompt.kind == .install ? privateBrowsingSwitch.isOn : false
            )
        )
        dismiss(animated: true)
    }
    
    private func promptMessage() -> String {
        let addonName = prompt.addon.metaData.name ?? prompt.addon.id
        
        switch prompt.kind {
        case .install:
            return "Add \(addonName)?"
        case .optional:
            if prompt.permissions.isEmpty && prompt.origins.isEmpty && !prompt.dataCollectionPermissions.isEmpty {
                return "\(addonName) requests additional data collection."
            }
            return "\(addonName) requests additional permissions."
        case .update:
            return "\(addonName) has been updated. You must approve additional permissions before the updated version will install. Dismissing this prompt will maintain your current add-on version."
        }
    }
    
    private var displayItems: [DisplayItem] {
        var items: [DisplayItem] = []
        
        if !domainRows.isEmpty {
            items.append(.domainHeader("Access your data for sites in \(domainRows.count) domains"))
            
            domainRows.prefix(Self.contractedDomainCount).forEach { items.append(.domain($0)) }
            
            if domainRows.count > Self.contractedDomainCount {
                items.append(.showAllSites)
            }
        }
        
        permissionRows.forEach { items.append(.permission($0)) }
        
        if let dataCollectionDescription {
            items.append(.dataCollection(dataCollectionDescription))
        }
        
        return items
    }
    
    private static func promptContent(
        for prompt: AddonPermissionPrompt
    ) -> (permissionRows: [String], domainRows: [String], dataCollectionDescription: String?) {
        switch prompt.kind {
        case .install, .optional:
            let hostPermissions = AddonPermissionSupport.classifyOriginPermissions(prompt.origins)
            let allUrlsPermissionFound = prompt.permissions.contains("<all_urls>") || hostPermissions.allUrls != nil
            var displayPermissions = prompt.permissions.filter { $0 != "<all_urls>" }
            if allUrlsPermissionFound {
                displayPermissions.insert("<all_urls>", at: 0)
            }
            
            let filteredDataCollectionPermissions = prompt.kind == .optional
            ? prompt.dataCollectionPermissions
            : prompt.dataCollectionPermissions.filter { $0 != "technicalAndInteraction" }
            
            return (
                permissionRows: AddonPermissionSupport.localizePermissions(displayPermissions, forUpdate: false),
                domainRows: allUrlsPermissionFound ? [] : (hostPermissions.wildcards + hostPermissions.sites),
                dataCollectionDescription: prompt.kind == .optional
                ? AddonPermissionSupport.optionalDataCollectionDescription(for: filteredDataCollectionPermissions)
                : AddonPermissionSupport.requiredDataCollectionDescription(for: filteredDataCollectionPermissions)
            )
        case .update:
            return (
                permissionRows: AddonPermissionSupport.updatePermissionDescription(for: prompt.permissions + prompt.origins).map { [$0] } ?? [],
                domainRows: [],
                dataCollectionDescription: AddonPermissionSupport.updateDataCollectionDescription(for: prompt.dataCollectionPermissions)
            )
        }
    }
    
    private static func promptTitle(for prompt: AddonPermissionPrompt) -> String {
        switch prompt.kind {
        case .install:
            return "Add Add-on"
        case .optional, .update:
            return "Update Add-on Permissions"
        }
    }
    
}

private final class AddonPromptSitesViewController: UITableViewController {
    private let sites: [String]
    
    init(sites: [String]) {
        self.sites = sites
        super.init(style: .insetGrouped)
        title = "Sites"
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        navigationItem.largeTitleDisplayMode = .never
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sites.count
    }
    
    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SiteCell")
        ?? UITableViewCell(style: .default, reuseIdentifier: "SiteCell")
        cell.selectionStyle = .none
        cell.textLabel?.numberOfLines = 0
        cell.textLabel?.text = sites[indexPath.row]
        return cell
    }
}
