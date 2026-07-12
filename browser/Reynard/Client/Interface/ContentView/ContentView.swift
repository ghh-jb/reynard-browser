//
//  ContentView.swift
//  Reynard
//
//  Created by Minh Ton on 10/6/26.
//

import GeckoView
import UIKit

final class ContentView: UIView, UIGestureRecognizerDelegate {
    private enum UX {
        static let phoneSearchFocusedBottomInset: CGFloat = 94
        static let focusedInputBottomClearance: CGFloat = 12
        static let focusedInputOffsetThreshold: CGFloat = 0.5
        static let historyPreviewParallaxRatio: CGFloat = 0.33
        static let historyTransitionProjectionDuration: CGFloat = 0.2
        static let historyTransitionDuration: TimeInterval = 0.35
    }
    
    private enum HistorySwipeDirection: Equatable {
        case back
        case forward
    }
    
    private enum HistorySwipeState {
        case idle // No history swipe is active.
        case swiping(HistorySwipeDirection) // Gesture is tracking the user's drag.
        case settling // Swipe completed; finish animation is running.
        case settled // Location changed before finish animation ended.
        case loaded // Page load completed before finish animation ended.
        case loading // Finish animation ended; waiting for page load.
        case resetting // Location changed without a load; reset on next run loop.
    }
    
    struct State: Equatable {
        let webVisibility: WebContentView.VisibilityState
        let overlayPresentation: OverlayContentView.PresentationState
        
        static let browsing = State(
            webVisibility: .visible,
            overlayPresentation: .hidden
        )
    }
    
    struct LayoutState: Equatable {
        enum Mode: Equatable {
            case standard
            case searchFocused
            case fullscreen
        }
        
        let mode: Mode
    }
    
    private(set) var state: State = .browsing
    private var layoutState = LayoutState(mode: .standard)
    private var session: GeckoSession?
    private var focusedInputTask: Task<Void, Never>?
    private var inputBottomRatio: CGFloat?
    private var focusedInputOffset: CGFloat = 0
    
    private var canGoBack = false
    private var canGoForward = false
    private var backPreviewImage: UIImage?
    private var forwardPreviewImage: UIImage?
    private var isHistorySwipeEnabled = false
    private var historySwipeState = HistorySwipeState.idle
    private var webContentSize: CGSize?
    
    private let webContentView = WebContentView()
    private let overlayContentView = OverlayContentView()
    private let historyPreviewImageView = UIImageView()
    
    var onBack: (() -> Void)?
    var onForward: (() -> Void)?
    var onHistorySwipeBegan: (() -> Void)?
    
    private var topConstraint: NSLayoutConstraint?
    private var bottomConstraint: NSLayoutConstraint?
    
    // MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureAppearance()
        configureHierarchy()
        configureConstraints()
        configureHistoryNavigation()
        applyState()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        focusedInputTask?.cancel()
    }
    
    // MARK: - Configuration
    
    private func configureAppearance() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .systemBackground
    }
    
    private func configureHierarchy() {
        webContentView.translatesAutoresizingMaskIntoConstraints = false
        historyPreviewImageView.translatesAutoresizingMaskIntoConstraints = false
        overlayContentView.translatesAutoresizingMaskIntoConstraints = false
        historyPreviewImageView.isHidden = true
        historyPreviewImageView.backgroundColor = .systemBackground
        historyPreviewImageView.contentMode = .scaleAspectFill
        historyPreviewImageView.clipsToBounds = true
        addSubview(webContentView)
        addSubview(historyPreviewImageView)
        addSubview(overlayContentView)
    }
    
    private func configureConstraints() {
        [webContentView, historyPreviewImageView, overlayContentView].forEach { contentView in
            NSLayoutConstraint.activate([
                contentView.topAnchor.constraint(equalTo: topAnchor),
                contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
                contentView.trailingAnchor.constraint(equalTo: trailingAnchor),
                contentView.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
        }
    }
    
    private func configureHistoryNavigation() {
        let backGesture = UIScreenEdgePanGestureRecognizer(
            target: self,
            action: #selector(handleBackHistoryPan(_:))
        )
        backGesture.edges = .left
        backGesture.delegate = self
        addGestureRecognizer(backGesture)
        
        let forwardGesture = UIScreenEdgePanGestureRecognizer(
            target: self,
            action: #selector(handleForwardHistoryPan(_:))
        )
        forwardGesture.edges = .right
        forwardGesture.delegate = self
        addGestureRecognizer(forwardGesture)
    }
    
    // MARK: - Layout
    
    func applyLayout(
        _ layoutState: LayoutState,
        topAnchor: NSLayoutYAxisAnchor,
        bottomAnchor: NSLayoutYAxisAnchor
    ) {
        self.layoutState = layoutState
        applyLayoutState(topAnchor: topAnchor, bottomAnchor: bottomAnchor)
    }
    
    func updateWebContentSize() -> Bool {
        let size = webContentView.bounds.size
        guard size.width > 1, size.height > 1 else {
            return false
        }
        defer { webContentSize = size }
        
        guard let previousSize = webContentSize else {
            return false
        }
        
        return previousSize != size
    }
    
    private func applyLayoutState(
        topAnchor: NSLayoutYAxisAnchor,
        bottomAnchor: NSLayoutYAxisAnchor
    ) {
        let nextTopConstraint = self.topAnchor.constraint(equalTo: topAnchor)
        let nextBottomConstraint = self.bottomAnchor.constraint(equalTo: bottomAnchor)
        guard canActivateConstraints([nextTopConstraint, nextBottomConstraint]) else {
            return
        }
        
        topConstraint?.isActive = false
        bottomConstraint?.isActive = false
        
        NSLayoutConstraint.activate([nextTopConstraint, nextBottomConstraint])
        topConstraint = nextTopConstraint
        bottomConstraint = nextBottomConstraint
        updateLayoutOffsets()
    }
    
    private func canActivateConstraints(_ constraints: [NSLayoutConstraint]) -> Bool {
        constraints.allSatisfy { constraint in
            guard let firstView = owningView(for: constraint.firstItem),
                  let secondView = owningView(for: constraint.secondItem) else {
                return true
            }
            
            return firstView.hasCommonAncestor(with: secondView)
        }
    }
    
    private func owningView(for item: Any?) -> UIView? {
        if let view = item as? UIView {
            return view
        }
        
        if let layoutGuide = item as? UILayoutGuide {
            return layoutGuide.owningView
        }
        
        return nil
    }
    
    private func updateLayoutOffsets() {
        topConstraint?.constant = layoutState.mode == .fullscreen ? 0 : -focusedInputOffset
        switch layoutState.mode {
        case .standard:
            bottomConstraint?.constant = -focusedInputOffset
        case .searchFocused:
            bottomConstraint?.constant = -UX.phoneSearchFocusedBottomInset
        case .fullscreen:
            bottomConstraint?.constant = 0
        }
    }
    
    // MARK: - Focused Input Relocation
    
    func relocateFocusedInput(
        above keyboardFrame: CGRect,
        animationDuration: TimeInterval,
        animationOptions: UIView.AnimationOptions
    ) {
        focusedInputTask?.cancel()
        guard let session else {
            resetFocusedInputRelocation(
                animationDuration: animationDuration,
                animationOptions: animationOptions
            )
            return
        }
        
        focusedInputTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let bottomRatio = await session.focusedInputBottomRatio()
            guard !Task.isCancelled else { return }
            
            inputBottomRatio = bottomRatio
            superview?.layoutIfNeeded()
            let newOffset = calculateFocusedInputOffset(keyboardFrame: keyboardFrame)
            guard abs(newOffset - focusedInputOffset) > UX.focusedInputOffsetThreshold else {
                return
            }
            
            focusedInputOffset = newOffset
            updateLayoutOffsets()
            animateLayout(duration: animationDuration, options: animationOptions)
        }
    }
    
    private func calculateFocusedInputOffset(keyboardFrame: CGRect) -> CGFloat {
        guard let inputBottomRatio else { return 0 }
        
        let unshiftedFrame = frame.offsetBy(dx: 0, dy: focusedInputOffset)
        guard unshiftedFrame.height > 1 else { return 0 }
        
        let keyboardOverlap = max(0, unshiftedFrame.maxY - keyboardFrame.minY)
        guard keyboardOverlap > 0 else { return 0 }
        
        let focusBottom = unshiftedFrame.height * inputBottomRatio
        let visibleBottom = max(
            0,
            unshiftedFrame.height - keyboardOverlap - UX.focusedInputBottomClearance
        )
        return min(keyboardOverlap, max(0, focusBottom - visibleBottom))
    }
    
    func resetFocusedInputRelocation(
        animationDuration: TimeInterval = 0,
        animationOptions: UIView.AnimationOptions = []
    ) {
        focusedInputTask?.cancel()
        focusedInputTask = nil
        inputBottomRatio = nil
        guard focusedInputOffset != 0 else { return }
        
        focusedInputOffset = 0
        updateLayoutOffsets()
        animateLayout(duration: animationDuration, options: animationOptions)
    }
    
    private func animateLayout(duration: TimeInterval, options: UIView.AnimationOptions) {
        guard duration > 0 else {
            superview?.layoutIfNeeded()
            return
        }
        
        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: [options, .beginFromCurrentState, .allowUserInteraction]
        ) {
            self.superview?.layoutIfNeeded()
        }
    }
    
    // MARK: - State
    
    func setState(_ state: State) {
        guard self.state != state else {
            return
        }
        
        self.state = state
        applyState()
    }
    
    func setWebVisibility(_ visibility: WebContentView.VisibilityState) {
        setState(State(
            webVisibility: visibility,
            overlayPresentation: state.overlayPresentation
        ))
    }
    
    func setOverlayPresentation(
        _ presentation: OverlayContentView.PresentationState,
        animated: Bool,
        completion: (() -> Void)? = nil
    ) {
        self.state = State(
            webVisibility: state.webVisibility,
            overlayPresentation: presentation
        )
        webContentView.setVisibility(state.webVisibility)
        overlayContentView.setPresentation(presentation, animated: animated, completion: completion)
    }
    
    private func applyState() {
        webContentView.setVisibility(state.webVisibility)
        overlayContentView.setPresentation(state.overlayPresentation, animated: false)
    }
    
    // MARK: - Session
    
    func setSession(_ session: GeckoSession?) {
        resetHistoryNavigation()
        self.session = session
        resetFocusedInputRelocation()
        webContentView.setSession(session)
    }
    
    func isDisplaying(session: GeckoSession) -> Bool {
        webContentView.isDisplaying(session: session)
    }
    
    func restoreInteraction(for session: GeckoSession) {
        webContentView.restoreInteraction(for: session)
    }
    
    // MARK: - Interaction
    
    func addWebViewInteraction(_ interaction: UIInteraction) {
        webContentView.addWebViewInteraction(interaction)
    }
    
    // MARK: - History Navigation
    
    func setHistoryNavigation(
        canGoBack: Bool,
        canGoForward: Bool,
        backPreviewImage: UIImage?,
        forwardPreviewImage: UIImage?,
        isSwipeEnabled: Bool
    ) {
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward
        self.backPreviewImage = backPreviewImage
        self.forwardPreviewImage = forwardPreviewImage
        isHistorySwipeEnabled = isSwipeEnabled
    }
    
    @objc private func handleBackHistoryPan(_ gesture: UIScreenEdgePanGestureRecognizer) {
        handleHistoryPan(gesture, direction: .back)
    }
    
    @objc private func handleForwardHistoryPan(_ gesture: UIScreenEdgePanGestureRecognizer) {
        handleHistoryPan(gesture, direction: .forward)
    }
    
    private func handleHistoryPan(
        _ gesture: UIScreenEdgePanGestureRecognizer,
        direction: HistorySwipeDirection
    ) {
        switch gesture.state {
        case .began:
            beginHistoryNavigation(direction)
        case .changed:
            updateHistoryNavigation(gesture, direction: direction)
        case .ended:
            finishHistoryNavigation(gesture, direction: direction, cancelled: false)
        case .cancelled, .failed:
            finishHistoryNavigation(gesture, direction: direction, cancelled: true)
        default:
            break
        }
    }
    
    private func beginHistoryNavigation(_ direction: HistorySwipeDirection) {
        guard case .idle = historySwipeState else {
            return
        }
        
        onHistorySwipeBegan?()
        historySwipeState = .swiping(direction)
        historyPreviewImageView.image = direction == .back ? backPreviewImage : forwardPreviewImage
        historyPreviewImageView.isHidden = false
        
        let width = bounds.width
        switch direction {
        case .back:
            insertSubview(historyPreviewImageView, belowSubview: webContentView)
            historyPreviewImageView.transform = CGAffineTransform(
                translationX: -width * UX.historyPreviewParallaxRatio,
                y: 0
            )
        case .forward:
            insertSubview(historyPreviewImageView, aboveSubview: webContentView)
            historyPreviewImageView.transform = CGAffineTransform(translationX: width, y: 0)
        }
    }
    
    private func updateHistoryNavigation(
        _ gesture: UIScreenEdgePanGestureRecognizer,
        direction: HistorySwipeDirection
    ) {
        guard case .swiping(let activeDirection) = historySwipeState,
              activeDirection == direction else {
            return
        }
        
        let progress = historyNavigationProgress(for: gesture, direction: direction)
        let width = bounds.width
        switch direction {
        case .back:
            webContentView.transform = CGAffineTransform(translationX: width * progress, y: 0)
            historyPreviewImageView.transform = CGAffineTransform(
                translationX: -width * UX.historyPreviewParallaxRatio * (1 - progress),
                y: 0
            )
        case .forward:
            historyPreviewImageView.transform = CGAffineTransform(
                translationX: width * (1 - progress),
                y: 0
            )
        }
    }
    
    private func finishHistoryNavigation(
        _ gesture: UIScreenEdgePanGestureRecognizer,
        direction: HistorySwipeDirection,
        cancelled: Bool
    ) {
        guard case .swiping(let activeDirection) = historySwipeState,
              activeDirection == direction else {
            resetHistoryNavigation()
            return
        }
        
        let progress = historyNavigationProgress(for: gesture, direction: direction)
        let velocityX = gesture.velocity(in: self).x
        let directionalVelocity: CGFloat
        switch direction {
        case .back:
            directionalVelocity = max(velocityX, 0)
        case .forward:
            directionalVelocity = max(-velocityX, 0)
        }
        
        let width = bounds.width
        let projectedDistance = width * progress
        + directionalVelocity * UX.historyTransitionProjectionDuration
        let shouldComplete = !cancelled && projectedDistance >= width
        
        UIView.animate(
            withDuration: UX.historyTransitionDuration,
            delay: 0,
            usingSpringWithDamping: 1,
            initialSpringVelocity: abs(velocityX) / max(width, 1),
            options: [.beginFromCurrentState, .allowUserInteraction]
        ) {
            if shouldComplete {
                self.historySwipeState = .settling
                switch direction {
                case .back:
                    self.webContentView.transform = CGAffineTransform(translationX: width, y: 0)
                    self.historyPreviewImageView.transform = .identity
                    self.onBack?()
                case .forward:
                    self.historyPreviewImageView.transform = .identity
                    self.onForward?()
                }
            } else {
                self.webContentView.transform = .identity
                switch direction {
                case .back:
                    self.historyPreviewImageView.transform = CGAffineTransform(
                        translationX: -width * UX.historyPreviewParallaxRatio,
                        y: 0
                    )
                case .forward:
                    self.historyPreviewImageView.transform = CGAffineTransform(translationX: width, y: 0)
                }
            }
        } completion: { _ in
            guard shouldComplete else {
                self.resetHistoryNavigation()
                return
            }
            
            if case .loaded = self.historySwipeState {
                self.resetHistoryNavigation()
                return
            }
            
            switch self.historySwipeState {
            case .settling:
                self.historySwipeState = .loading
            case .settled:
                self.scheduleHistoryLocationReset()
            default:
                break
            }
        }
    }
    
    private func historyNavigationProgress(
        for gesture: UIScreenEdgePanGestureRecognizer,
        direction: HistorySwipeDirection
    ) -> CGFloat {
        let translationX = gesture.translation(in: self).x
        let distance: CGFloat
        switch direction {
        case .back:
            distance = translationX
        case .forward:
            distance = -translationX
        }
        return min(max(distance / max(bounds.width, 1), 0), 1)
    }
    
    private func resetHistoryNavigation() {
        webContentView.transform = .identity
        historyPreviewImageView.transform = .identity
        historyPreviewImageView.image = nil
        historyPreviewImageView.isHidden = true
        historySwipeState = .idle
    }
    
    func finishHistoryLoad() {
        switch historySwipeState {
        case .settling, .settled:
            historySwipeState = .loaded
        case .loading, .resetting:
            resetHistoryNavigation()
        case .idle, .swiping, .loaded:
            break
        }
    }
    
    func noteHistoryLocationChange() {
        switch historySwipeState {
        case .settling:
            historySwipeState = .settled
        case .loading:
            scheduleHistoryLocationReset()
        case .idle, .swiping, .settled, .loaded, .resetting:
            break
        }
    }
    
    private func scheduleHistoryLocationReset() {
        historySwipeState = .resetting
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  case .resetting = self.historySwipeState else {
                return
            }
            
            self.resetHistoryNavigation()
        }
    }
    
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer is UIScreenEdgePanGestureRecognizer,
              case .idle = historySwipeState,
              isHistorySwipeEnabled,
              state == .browsing,
              webContentView.visibility == .visible else {
            return false
        }
        
        if let backGesture = gestureRecognizer as? UIScreenEdgePanGestureRecognizer,
           backGesture.edges == .left {
            return canGoBack
        }
        
        return canGoForward
    }
    
    // MARK: - Presentation
    
    func setTransitionTransform(_ transform: CGAffineTransform) {
        self.transform = transform
    }
    
    func setTransitionHidden(_ hidden: Bool) {
        isHidden = hidden
    }
    
    func frame(in view: UIView) -> CGRect {
        convert(bounds, to: view)
    }
    
    // MARK: - Thumbnail
    
    func makeWebThumbnail() -> UIImage? {
        return webContentView.makeThumbnail()
    }
    
    // MARK: - Overlay Hosting
    
    func setOverlayController(
        _ viewController: UIViewController,
        for page: OverlayContentView.Page,
        in parentViewController: UIViewController
    ) {
        overlayContentView.setController(viewController, for: page, in: parentViewController)
    }
    
    func removeOverlayController(for page: OverlayContentView.Page) {
        overlayContentView.removeController(for: page)
    }
    
}
