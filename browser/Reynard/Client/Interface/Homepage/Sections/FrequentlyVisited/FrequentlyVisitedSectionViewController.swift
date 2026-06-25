//
//  FrequentlyVisitedSectionViewController.swift
//  Reynard
//
//  Created by Minh Ton on 24/6/26.
//

import UIKit

final class FrequentlyVisitedSectionViewController: UIViewController {
    private enum UX {
        static let horizontalInset: CGFloat = 2
        static let titleTopSpacing: CGFloat = 16
        static let titleBottomSpacing: CGFloat = 14
        static let titleFontSize: CGFloat = 22
        static let cardWidth: CGFloat = 150
        static let cardHeight: CGFloat = 120
        static let cardSpacing: CGFloat = 16
        static let shadowMargin: CGFloat = 20
        static let maximumSiteCount = 8
        static let minimumVisitCount = 3
    }
    
    private enum MetadataState {
        case loading(Task<Void, Never>)
        case loaded(SiteMetadataSnapshot)
        
        func cancelLoad() {
            guard case let .loading(task) = self else {
                return
            }
            
            task.cancel()
        }
    }
    
    private static let titleFont = UIFontMetrics(forTextStyle: .title2).scaledFont(
        for: .systemFont(ofSize: UX.titleFontSize, weight: .bold)
    )
    
    weak var delegate: HomepageSectionDelegate?
    
    private let historyStore: HistoryStore
    private let metadataStore: SiteMetadataStore
    private var sites: [HistorySiteSnapshot] = []
    private var metadataStatesByURL: [URL: MetadataState] = [:]
    private var cardViews: [FrequentlyVisitedSiteCardView] = []
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = FrequentlyVisitedSectionViewController.titleFont
        label.textColor = .label
        label.text = "Frequently Visited"
        label.adjustsFontForContentSizeCategory = true
        return label
    }()
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = .clear
        scrollView.showsHorizontalScrollIndicator = false
        return scrollView
    }()
    
    private let cardStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.alignment = .fill
        stackView.distribution = .fill
        stackView.spacing = UX.cardSpacing
        return stackView
    }()
    
    // MARK: - Lifecycle
    
    init(historyStore: HistoryStore = .shared, metadataStore: SiteMetadataStore = .shared) {
        self.historyStore = historyStore
        self.metadataStore = metadataStore
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        cancelMetadataLoads()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureAppearance()
        configureHierarchy()
        configureConstraints()
        observeHistory()
        reloadSites()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        resetScrollPosition()
    }
    
    // MARK: - Configuration
    
    private func configureAppearance() {
        view.backgroundColor = .clear
    }
    
    private func configureHierarchy() {
        view.addSubview(titleLabel)
        view.addSubview(scrollView)
        scrollView.addSubview(cardStackView)
    }
    
    private func configureConstraints() {
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: UX.titleTopSpacing),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: UX.horizontalInset),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -UX.horizontalInset),
            
            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: UX.titleBottomSpacing - UX.shadowMargin),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: -UX.shadowMargin),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: UX.shadowMargin),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.heightAnchor.constraint(equalToConstant: UX.cardHeight + (UX.shadowMargin * 2)),
            
            cardStackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: UX.shadowMargin),
            cardStackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -UX.shadowMargin),
            cardStackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: UX.shadowMargin),
            cardStackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -UX.shadowMargin),
            cardStackView.heightAnchor.constraint(equalToConstant: UX.cardHeight),
        ])
    }
    
    private func observeHistory() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(historyDidChange),
            name: .historyStoreDidChange,
            object: nil
        )
    }
    
    // MARK: - History
    
    private func reloadSites() {
        sites = historyStore.frequentSites(
            limit: UX.maximumSiteCount,
            minVisitCount: UX.minimumVisitCount
        ).items
        let retainedURLs = Set(sites.map(\.url))
        metadataStatesByURL = metadataStatesByURL.filter { url, state in
            if retainedURLs.contains(url) {
                return true
            }
            
            state.cancelLoad()
            return false
        }
        
        metadataStore.prune(keeping: sites.map(\.url))
        reloadCardViews()
        view.isHidden = sites.isEmpty
    }
    
    @objc private func historyDidChange() {
        reloadSites()
    }
    
    // MARK: - Misc
    
    private func resetScrollPosition() {
        scrollView.setContentOffset(.zero, animated: false)
    }
    
    // MARK: - Metadata
    
    private func metadata(for site: HistorySiteSnapshot) -> SiteMetadataSnapshot? {
        if case let .loaded(metadata) = metadataStatesByURL[site.url] {
            return metadata
        }
        
        if let cachedMetadata = metadataStore.cachedMetadata(for: site.url) {
            metadataStatesByURL[site.url] = .loaded(cachedMetadata)
            return cachedMetadata
        }
        
        loadMetadata(for: site.url)
        return nil
    }
    
    private func loadMetadata(for url: URL) {
        guard metadataStatesByURL[url] == nil else {
            return
        }
        
        let task = Task { [weak self] in
            guard let self else {
                return
            }
            
            let metadata = await self.metadataStore.metadata(for: url)
            guard !Task.isCancelled else {
                return
            }
            
            await MainActor.run {
                guard let metadata,
                      self.sites.contains(where: { $0.url == url }) else {
                    self.metadataStatesByURL[url] = nil
                    return
                }
                
                self.metadataStatesByURL[url] = .loaded(metadata)
                if let index = self.sites.firstIndex(where: { $0.url == url }) {
                    self.cardViews[index].configure(site: self.sites[index], metadata: metadata)
                }
            }
        }
        
        metadataStatesByURL[url] = .loading(task)
    }
    
    private func cancelMetadataLoads() {
        metadataStatesByURL.values.forEach { $0.cancelLoad() }
    }
    
    // MARK: - Layout
    
    private func reloadCardViews() {
        for cardView in cardViews {
            cardView.removeFromSuperview()
        }
        
        cardViews = sites.enumerated().map { index, site in
            let cardView = FrequentlyVisitedSiteCardView()
            cardView.translatesAutoresizingMaskIntoConstraints = false
            cardView.tag = index
            cardView.configure(site: site, metadata: metadata(for: site))
            cardView.addTarget(self, action: #selector(handleCardTap(_:)), for: .touchUpInside)
            cardStackView.addArrangedSubview(cardView)
            
            NSLayoutConstraint.activate([
                cardView.widthAnchor.constraint(equalToConstant: UX.cardWidth),
                cardView.heightAnchor.constraint(equalToConstant: UX.cardHeight),
            ])
            
            return cardView
        }
    }
    
    // MARK: - Actions
    
    @objc private func handleCardTap(_ sender: FrequentlyVisitedSiteCardView) {
        guard sites.indices.contains(sender.tag) else {
            return
        }
        
        delegate?.homepageSection(self, didSelectURL: sites[sender.tag].url)
    }
}
