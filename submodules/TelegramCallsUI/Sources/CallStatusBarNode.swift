import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import LegacyComponents

private let blue = UIColor(rgb: 0x0078ff)
private let lightBlue = UIColor(rgb: 0x59c7f8)
private let green = UIColor(rgb: 0x33c659)

private class CallStatusBarBackgroundNode: ASDisplayNode {
    private let foregroundView: UIView
    private let foregroundGradientLayer: CAGradientLayer
    private let maskCurveView: VoiceCurveView
    
    var audioLevel: Float = 0.0  {
        didSet {
            self.maskCurveView.updateLevel(CGFloat(audioLevel))
        }
    }
    
    var speaking = false {
        didSet {
            if self.speaking != oldValue {
                let initialColors = self.foregroundGradientLayer.colors
                let targetColors: [CGColor]
                if speaking {
                    targetColors = [green.cgColor, blue.cgColor]
                } else {
                    targetColors = [blue.cgColor, lightBlue.cgColor]
                }
                self.foregroundGradientLayer.colors = targetColors
                self.foregroundGradientLayer.animate(from: initialColors as AnyObject, to: targetColors as AnyObject, keyPath: "colors", timingFunction: CAMediaTimingFunctionName.linear.rawValue, duration: 0.3)
            }
        }
    }
    
    private let hierarchyTrackingNode: HierarchyTrackingNode
    private var isCurrentlyInHierarchy = true

    override init() {
        self.foregroundView = UIView()
        self.foregroundGradientLayer = CAGradientLayer()
        self.maskCurveView = VoiceCurveView(frame: CGRect(), maxLevel: 2.5, smallCurveRange: (0.0, 0.0), mediumCurveRange: (0.1, 0.55), bigCurveRange: (0.1, 1.0))
        self.maskCurveView.setColor(UIColor(rgb: 0xffffff))
        
        var updateInHierarchy: ((Bool) -> Void)?
        self.hierarchyTrackingNode = HierarchyTrackingNode({ value in
            updateInHierarchy?(value)
        })
        
        super.init()
        
        self.addSubnode(self.hierarchyTrackingNode)
        
        self.foregroundGradientLayer.colors = [blue.cgColor, lightBlue.cgColor]
        self.foregroundGradientLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
        self.foregroundGradientLayer.endPoint = CGPoint(x: 2.0, y: 0.5)
        
        self.foregroundView.mask = self.maskCurveView
        
        self.isOpaque = false
        
        self.updateAnimations()
        
        updateInHierarchy = { [weak self] value in
            if let strongSelf = self {
                strongSelf.isCurrentlyInHierarchy = value
                strongSelf.updateAnimations()
            }
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addSubview(self.foregroundView)
        self.foregroundView.layer.addSublayer(self.foregroundGradientLayer)
    }
    
    override func layout() {
        super.layout()
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if self.maskCurveView.frame != self.bounds {
            self.foregroundView.frame = self.bounds
            self.foregroundGradientLayer.frame = self.bounds
            self.maskCurveView.frame = self.bounds
        }
        CATransaction.commit()
    }
    
    private func setupGradientAnimations() {
        return
        if let _ = self.foregroundGradientLayer.animation(forKey: "movement") {
        } else {
            let previousValue = self.foregroundGradientLayer.startPoint
            let newValue: CGPoint
            if self.maskCurveView.presentationAudioLevel > 0.1 {
                newValue = CGPoint(x: CGFloat.random(in: 1.0 ..< 1.3), y: 0.5)
            } else {
                newValue = CGPoint(x: CGFloat.random(in: 0.85 ..< 1.2), y: 0.5)
            }
            self.foregroundGradientLayer.startPoint = newValue
            
            CATransaction.begin()
            
            let animation = CABasicAnimation(keyPath: "endPoint")
            animation.duration = Double.random(in: 0.8 ..< 1.4)
            animation.fromValue = previousValue
            animation.toValue = newValue
            
            CATransaction.setCompletionBlock { [weak self] in
                self?.setupGradientAnimations()
            }
            
            self.foregroundGradientLayer.add(animation, forKey: "movement")
            CATransaction.commit()
        }
    }
    
    func updateAnimations() {
        if !isCurrentlyInHierarchy {
            self.foregroundGradientLayer.removeAllAnimations()
            self.maskCurveView.stopAnimating()
            return
        }
        self.setupGradientAnimations()
        self.maskCurveView.startAnimating()
    }
}

public class CallStatusBarNodeImpl: CallStatusBarNode {
    public enum Content {
        case call(SharedAccountContext, Account, PresentationCall)
        case groupCall(SharedAccountContext, Account, PresentationGroupCall)
    }
    
    private let backgroundNode: CallStatusBarBackgroundNode
    private let microphoneNode: VoiceChatMicrophoneNode
    private let titleNode: ImmediateTextNode
    private let subtitleNode: ImmediateTextNode
    
    private let audioLevelDisposable = MetaDisposable()
    private let stateDisposable = MetaDisposable()
    private var didSetupData = false
    
    private var currentSize: CGSize?
    private var currentContent: Content?
    
    private var strings: PresentationStrings?
    private var nameDisplayOrder: PresentationPersonNameOrder = .firstLast
    private var currentPeer: Peer?
    private var currentCallTimer: SwiftSignalKit.Timer?
    private var currentCallState: PresentationCallState?
    private var currentGroupCallState: PresentationGroupCallSummaryState?
    private var currentIsMuted = true
    private var currentIsConnecting = true
    
    public override init() {
        self.backgroundNode = CallStatusBarBackgroundNode()
        self.microphoneNode = VoiceChatMicrophoneNode()
        self.titleNode = ImmediateTextNode()
        self.subtitleNode = ImmediateTextNode()
        
        super.init()
                
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.microphoneNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.subtitleNode)
    }
    
    deinit {
        self.audioLevelDisposable.dispose()
        self.stateDisposable.dispose()
        self.currentCallTimer?.invalidate()
    }
    
    public func update(content: Content) {
        self.currentContent = content
        self.update()
    }
    
    public override func update(size: CGSize) {
        self.currentSize = size
        self.update()
    }
    
    private func update() {
        guard let size = self.currentSize, let content = self.currentContent else {
            return
        }
        
        if !self.didSetupData {
            switch content {
                case let .call(sharedContext, account, call):
                    let presentationData = sharedContext.currentPresentationData.with { $0 }
                    self.strings = presentationData.strings
                    self.nameDisplayOrder = presentationData.nameDisplayOrder
                    self.stateDisposable.set(
                        (combineLatest(
                            account.postbox.loadedPeerWithId(call.peerId),
                            call.state,
                            call.isMuted
                        )
                    |> deliverOnMainQueue).start(next: { [weak self] peer, state, isMuted in
                        if let strongSelf = self {
                            strongSelf.currentPeer = peer
                            strongSelf.currentCallState = state
                            strongSelf.currentIsMuted = isMuted
                            strongSelf.update()
                        }
                    }))
                case let .groupCall(sharedContext, account, call):
                    let presentationData = sharedContext.currentPresentationData.with { $0 }
                    self.strings = presentationData.strings
                    self.nameDisplayOrder = presentationData.nameDisplayOrder
                    self.stateDisposable.set(
                        (combineLatest(
                            account.postbox.peerView(id: call.peerId),
                            call.summaryState,
                            call.isMuted
                        )
                    |> deliverOnMainQueue).start(next: { [weak self] view, state, isMuted in
                        if let strongSelf = self {
                            strongSelf.currentPeer = view.peers[view.peerId]
                            strongSelf.currentGroupCallState = state
                            strongSelf.currentIsMuted = isMuted
                            strongSelf.update()
                        }
                    }))
                    self.audioLevelDisposable.set((combineLatest(call.myAudioLevel, .single([]) |> then(call.audioLevels))
                    |> deliverOnMainQueue).start(next: { [weak self] myAudioLevel, audioLevels in
                        guard let strongSelf = self else {
                            return
                        }
                        var effectiveLevel: Float = 0.0
                        if !strongSelf.currentIsMuted {
                            effectiveLevel = myAudioLevel
                        } else {
                            effectiveLevel = audioLevels.map { $0.1 }.max() ?? 0.0
                        }
                        strongSelf.backgroundNode.audioLevel = effectiveLevel
                    }))
            }
            self.didSetupData = true
        }
        
        var title: String = ""
        var subtitle: String = ""
        
        if let strings = self.strings {
            if let currentPeer = self.currentPeer {
                title = currentPeer.displayTitle(strings: strings, displayOrder: self.nameDisplayOrder)
            }
            var membersCount: Int32?
            if let groupCallState = self.currentGroupCallState {
                membersCount = Int32(max(1, groupCallState.participantCount))
            } else if let content = self.currentContent, case .groupCall = content {
                membersCount = 1
            }
            if let membersCount = membersCount {
                subtitle = strings.VoiceChat_Panel_Members(membersCount)
            }
        }
        self.titleNode.attributedText = NSAttributedString(string: title, font: Font.semibold(13.0), textColor: .white)
        self.subtitleNode.attributedText = NSAttributedString(string: subtitle, font: Font.regular(13.0), textColor: .white)
        
        let animationSize: CGFloat = 25.0
        let iconSpacing: CGFloat = 0.0
        let spacing: CGFloat = 5.0
        let titleSize = self.titleNode.updateLayout(CGSize(width: 160.0, height: size.height))
        let subtitleSize = self.subtitleNode.updateLayout(CGSize(width: 160.0, height: size.height))
        
        let totalWidth = animationSize + iconSpacing + titleSize.width + spacing + subtitleSize.width
        let horizontalOrigin: CGFloat = floor((size.width - totalWidth) / 2.0)
        
        let contentHeight: CGFloat = 24.0
        let verticalOrigin: CGFloat = size.height - contentHeight
        
        self.microphoneNode.frame = CGRect(origin: CGPoint(x: horizontalOrigin, y: verticalOrigin + floor((contentHeight - animationSize) / 2.0)), size: CGSize(width: animationSize, height: animationSize))
        self.microphoneNode.update(state: VoiceChatMicrophoneNode.State(muted: self.currentIsMuted, color: UIColor.white), animated: true)
        
        self.titleNode.frame = CGRect(origin: CGPoint(x: horizontalOrigin + animationSize + iconSpacing, y: verticalOrigin + floor((contentHeight - titleSize.height) / 2.0)), size: titleSize)
        self.subtitleNode.frame = CGRect(origin: CGPoint(x: horizontalOrigin + animationSize + iconSpacing + titleSize.width + spacing, y: verticalOrigin + floor((contentHeight - subtitleSize.height) / 2.0)), size: subtitleSize)
        
        self.backgroundNode.speaking = !self.currentIsMuted
        self.backgroundNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height + 18.0))
    }
}

private final class VoiceCurveView: UIView {
    private let smallCurve: CurveView
    private let mediumCurve: CurveView
    private let bigCurve: CurveView
    
    private let maxLevel: CGFloat
    
    private var displayLinkAnimator: ConstantDisplayLinkAnimator?
    
    private var audioLevel: CGFloat = 0.0
    var presentationAudioLevel: CGFloat = 0.0
    
    private(set) var isAnimating = false
    
    public typealias CurveRange = (min: CGFloat, max: CGFloat)
    
    public init(
        frame: CGRect,
        maxLevel: CGFloat,
        smallCurveRange: CurveRange,
        mediumCurveRange: CurveRange,
        bigCurveRange: CurveRange
    ) {
        self.maxLevel = maxLevel
        
        self.smallCurve = CurveView(
            pointsCount: 7,
            minRandomness: 1,
            maxRandomness: 1.3,
            minSpeed: 0.9,
            maxSpeed: 3.2,
            minOffset: smallCurveRange.min,
            maxOffset: smallCurveRange.max
        )
        self.mediumCurve = CurveView(
            pointsCount: 7,
            minRandomness: 1.2,
            maxRandomness: 1.5,
            minSpeed: 1.0,
            maxSpeed: 4.4,
            minOffset: mediumCurveRange.min,
            maxOffset: mediumCurveRange.max
        )
        self.bigCurve = CurveView(
            pointsCount: 7,
            minRandomness: 1.2,
            maxRandomness: 1.7,
            minSpeed: 1.0,
            maxSpeed: 5.8,
            minOffset: bigCurveRange.min,
            maxOffset: bigCurveRange.max
        )
        
        super.init(frame: frame)
        
        addSubview(bigCurve)
        addSubview(mediumCurve)
        addSubview(smallCurve)
        
        displayLinkAnimator = ConstantDisplayLinkAnimator() { [weak self] in
            guard let strongSelf = self else { return }
            
            strongSelf.presentationAudioLevel = strongSelf.presentationAudioLevel * 0.9 + strongSelf.audioLevel * 0.1
            
            strongSelf.smallCurve.level = strongSelf.presentationAudioLevel
            strongSelf.mediumCurve.level = strongSelf.presentationAudioLevel
            strongSelf.bigCurve.level = strongSelf.presentationAudioLevel
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func setColor(_ color: UIColor) {
        smallCurve.setColor(color.withAlphaComponent(1.0))
        mediumCurve.setColor(color.withAlphaComponent(0.55))
        bigCurve.setColor(color.withAlphaComponent(0.35))
    }
    
    public func updateLevel(_ level: CGFloat) {
        let normalizedLevel = min(1, max(level / maxLevel, 0))
        
        smallCurve.updateSpeedLevel(to: normalizedLevel)
        mediumCurve.updateSpeedLevel(to: normalizedLevel)
        bigCurve.updateSpeedLevel(to: normalizedLevel)
        
        audioLevel = normalizedLevel
    }
    
    public func startAnimating() {
        guard !isAnimating else { return }
        isAnimating = true
        
        updateCurvesState()
        
        displayLinkAnimator?.isPaused = false
    }
    
    public func stopAnimating() {
        self.stopAnimating(duration: 0.15)
    }
    
    public func stopAnimating(duration: Double) {
        guard isAnimating else { return }
        isAnimating = false
        
        updateCurvesState()
        
        displayLinkAnimator?.isPaused = true
    }
    
    private func updateCurvesState() {
        if isAnimating {
            if smallCurve.frame.size != .zero {
                smallCurve.startAnimating()
                mediumCurve.startAnimating()
                bigCurve.startAnimating()
            }
        } else {
            smallCurve.stopAnimating()
            mediumCurve.stopAnimating()
            bigCurve.stopAnimating()
        }
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        smallCurve.frame = bounds
        mediumCurve.frame = bounds
        bigCurve.frame = bounds
        
        updateCurvesState()
    }
}

final class CurveView: UIView {
    let pointsCount: Int
    let smoothness: CGFloat
    
    let minRandomness: CGFloat
    let maxRandomness: CGFloat
    
    let minSpeed: CGFloat
    let maxSpeed: CGFloat
    
    let minOffset: CGFloat
    let maxOffset: CGFloat
        
    var level: CGFloat = 0 {
        didSet {
            guard self.minOffset > 0.0 else {
                return
            }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            let lv = minOffset + (maxOffset - minOffset) * level
            shapeLayer.transform = CATransform3DMakeTranslation(0.0, lv * 16.0, 0.0)
            CATransaction.commit()
        }
    }
    
    private var speedLevel: CGFloat = 0
    private var lastSpeedLevel: CGFloat = 0
    
    private let shapeLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.strokeColor = nil
        return layer
    }()
    
    private var transition: CGFloat = 0 {
        didSet {
            guard let currentPoints = currentPoints else { return }
            
            shapeLayer.path = UIBezierPath.smoothCurve(through: currentPoints, length: bounds.width, smoothness: smoothness, curve: true).cgPath
        }
    }
    
    override var frame: CGRect {
        didSet {
            if self.frame.size != oldValue.size {
                self.fromPoints = nil
                self.toPoints = nil
                self.animateToNewShape()
            }
        }
    }
    
    private var fromPoints: [CGPoint]?
    private var toPoints: [CGPoint]?
    
    private var currentPoints: [CGPoint]? {
        guard let fromPoints = fromPoints, let toPoints = toPoints else { return nil }
        
        return fromPoints.enumerated().map { offset, fromPoint in
            let toPoint = toPoints[offset]
            return CGPoint(
                x: fromPoint.x + (toPoint.x - fromPoint.x) * transition,
                y: fromPoint.y + (toPoint.y - fromPoint.y) * transition
            )
        }
    }
    
    init(
        pointsCount: Int,
        minRandomness: CGFloat,
        maxRandomness: CGFloat,
        minSpeed: CGFloat,
        maxSpeed: CGFloat,
        minOffset: CGFloat,
        maxOffset: CGFloat
    ) {
        self.pointsCount = pointsCount
        self.minRandomness = minRandomness
        self.maxRandomness = maxRandomness
        self.minSpeed = minSpeed
        self.maxSpeed = maxSpeed
        self.minOffset = minOffset
        self.maxOffset = maxOffset
        
        self.smoothness = 0.35
        
        super.init(frame: .zero)
        
        layer.addSublayer(shapeLayer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setColor(_ color: UIColor) {
        shapeLayer.fillColor = color.cgColor
    }
    
    func updateSpeedLevel(to newSpeedLevel: CGFloat) {
        speedLevel = max(speedLevel, newSpeedLevel)
        
        if abs(lastSpeedLevel - newSpeedLevel) > 0.45 {
            animateToNewShape()
        }
    }
    
    func startAnimating() {
        animateToNewShape()
    }
    
    func stopAnimating() {
        fromPoints = currentPoints
        toPoints = nil
        pop_removeAnimation(forKey: "curve")
    }
    
    private func animateToNewShape() {
        if pop_animation(forKey: "curve") != nil {
            fromPoints = currentPoints
            toPoints = nil
            pop_removeAnimation(forKey: "curve")
        }
        
        if fromPoints == nil {
            fromPoints = generateNextCurve(for: bounds.size)
        }
        if toPoints == nil {
            toPoints = generateNextCurve(for: bounds.size)
        }
        
        let animation = POPBasicAnimation()
        animation.property = POPAnimatableProperty.property(withName: "curve.transition", initializer: { property in
            property?.readBlock = { curveView, values in
                guard let curveView = curveView as? CurveView, let values = values else { return }
                
                values.pointee = curveView.transition
            }
            property?.writeBlock = { curveView, values in
                guard let curveView = curveView as? CurveView, let values = values else { return }
                
                curveView.transition = values.pointee
            }
        })  as? POPAnimatableProperty
        animation.completionBlock = { [weak self] animation, finished in
            if finished {
                self?.fromPoints = self?.currentPoints
                self?.toPoints = nil
                self?.animateToNewShape()
            }
        }
        animation.duration = CFTimeInterval(1 / (minSpeed + (maxSpeed - minSpeed) * speedLevel))
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animation.fromValue = 0
        animation.toValue = 1
        pop_add(animation, forKey: "curve")
        
        lastSpeedLevel = speedLevel
        speedLevel = 0
    }
    
    private func generateNextCurve(for size: CGSize) -> [CGPoint] {
        let randomness = minRandomness + (maxRandomness - minRandomness) * speedLevel
        return curve(pointsCount: pointsCount, randomness: randomness).map {
            return CGPoint(x: $0.x * CGFloat(size.width), y: size.height - 18.0 + $0.y * 12.0)
        }
    }

    private func curve(pointsCount: Int, randomness: CGFloat) -> [CGPoint] {
        let segment = 1.0 / CGFloat(pointsCount - 1)

        let rgen = { () -> CGFloat in
            let accuracy: UInt32 = 1000
            let random = arc4random_uniform(accuracy)
            return CGFloat(random) / CGFloat(accuracy)
        }
        let rangeStart: CGFloat = 1.0 / (1.0 + randomness / 10.0)

        let points = (0 ..< pointsCount).map { i -> CGPoint in
            let randPointOffset = (rangeStart + CGFloat(rgen()) * (1 - rangeStart)) / 2
            let segmentRandomness: CGFloat = randomness
            
            let pointX: CGFloat
            let pointY: CGFloat
            let randomXDelta: CGFloat
            if i == 0 {
                pointX = 0.0
                pointY = 0.0
                randomXDelta = 0.0
            } else if i == pointsCount - 1 {
                pointX = 1.0
                pointY = 0.0
                randomXDelta = 0.0
            } else {
                pointX = segment * CGFloat(i)
                pointY = ((segmentRandomness * CGFloat(arc4random_uniform(100)) / CGFloat(100)) - segmentRandomness * 0.5) * randPointOffset
                randomXDelta = segment - segment * randPointOffset
            }

            return CGPoint(x: pointX + randomXDelta, y: pointY)
        }

        return points
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shapeLayer.position = CGPoint(x: self.bounds.width / 2.0, y: self.bounds.height / 2.0)
        shapeLayer.bounds = self.bounds
        CATransaction.commit()
    }
}