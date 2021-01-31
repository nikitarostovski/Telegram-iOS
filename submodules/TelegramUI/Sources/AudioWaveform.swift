import Foundation
import UIKit
import AsyncDisplayKit
import Display

private func getBits(data: UnsafeRawPointer, length: Int, bitOffset: Int, numBits: Int) -> Int32 {
    let normalizedNumBits = Int(pow(2.0, Double(numBits))) - 1
    let byteOffset = bitOffset / 8
    let normalizedData = data.advanced(by: byteOffset)
    let normalizedBitOffset = bitOffset % 8
    
    var value: Int32 = 0
    if byteOffset + 4 > length {
        let remaining = length - byteOffset
        withUnsafeMutableBytes(of: &value, { (bytes: UnsafeMutableRawBufferPointer) -> Void in
            memcpy(bytes.baseAddress!, normalizedData, remaining)
        })
    } else {
        value = normalizedData.assumingMemoryBound(to: Int32.self).pointee
    }
    return (value >> Int32(normalizedBitOffset)) & Int32(normalizedNumBits)
}

private func setBits(data: UnsafeMutableRawPointer, bitOffset: Int, numBits: Int, value: Int32) {
    let normalizedData = data.advanced(by: bitOffset / 8)
    let normalizedBitOffset = bitOffset % 8
    
    normalizedData.assumingMemoryBound(to: Int32.self).pointee |= value << Int32(normalizedBitOffset)
}

final class AudioWaveform: Equatable {
    let samples: Data
    let peak: Int32
    
    init(samples: Data, peak: Int32) {
        self.samples = samples
        self.peak = peak
    }
    
    convenience init(bitstream: Data, bitsPerSample: Int) {
        let numSamples = Int(Float(bitstream.count * 8) / Float(bitsPerSample))
        var result = Data()
        result.count = numSamples * 2
        
        bitstream.withUnsafeBytes { (bytes: UnsafePointer<Int8>) -> Void in
            result.withUnsafeMutableBytes { (samples: UnsafeMutablePointer<Int16>) -> Void in
                let norm = Int64((1 << bitsPerSample) - 1)
                for i in 0 ..< numSamples {
                    samples[i] = Int16(Int64(getBits(data: bytes, length: bitstream.count, bitOffset: i * 5, numBits: 5)) * norm / norm)
                }
            }
        }
        
        self.init(samples: result, peak: 31)
    }
    
    func makeBitstream() -> Data {
        let numSamples = self.samples.count / 2
        let bitstreamLength = (numSamples * 5) / 8 + (((numSamples * 5) % 8) == 0 ? 0 : 1)
        var result = Data()
        result.count = bitstreamLength + 4
        
        let maxSample: Int32 = self.peak
        
        self.samples.withUnsafeBytes { (samples: UnsafePointer<Int16>) -> Void in
            result.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<Int16>) -> Void in
                for i in 0 ..< numSamples {
                    let value: Int32 = min(Int32(31), abs(Int32(samples[i])) * 31 / maxSample)
                    if i == 99 {
                        assert(true)
                    }
                    setBits(data: bytes, bitOffset: i * 5, numBits: 5, value: value & Int32(31))
                }
            }
        }
        
        result.count = bitstreamLength
        
        return result
    }
    
    static func ==(lhs: AudioWaveform, rhs: AudioWaveform) -> Bool {
        return lhs.peak == rhs.peak && lhs.samples == rhs.samples
    }
}

class AnimationManager {
    
    enum TapSource {
        case sendButton
        case mediaButton
        case sticker
    }
    
    enum MessageType {
        case textSmall
        case audio
        case video
        case sticker
        case emoji
        case link
    }
    
    static var shared = AnimationManager()
    var settings = AnimSettingsHandler.load()
    var shouldAnimateInsertion: Bool = false
    var tapSource: TapSource?
    private var nodesAnimating = [WeakRef<ASDisplayNode>]()
    
    var videoFrame: CGRect?
    

    var ySettings: AnimationCurve {
        let active = settings.activeSettings
        if let active = active as? SmallMessageSettings {
            return active.curveY
//        } else if let active = active as? BigMessageSettings {
//            return active.curveY
        } else if let active = active as? LinkWithPreviewSettings {
            return active.curveY
        } else if let active = active as? EmojiMessageSettings {
            return active.curveY
        } else if let active = active as? StickerMessageSettings {
            return active.curveY
        } else if let active = active as? VoiceMessageSettings {
            return active.curveY
        } else if let active = active as? VideoMessageSettings {
            return active.curveY
        }
        return AnimationCurve(tuple: (0, 0, 1, 1), delay: 0, duration: 0)
    }
    var yDuration: TimeInterval {
        (TimeInterval(ySettings.duration) + TimeInterval(ySettings.delay)) * TimeInterval(durationScale)
    }
    var yDelay: TimeInterval {
        0//TimeInterval(ySettings.delay)
    }
    var yCurve: (Float, Float, Float, Float) {
        ySettings.tuple
    }
    var curveFunctionY: CAMediaTimingFunction {
        CAMediaTimingFunction(controlPoints: yCurve.0, yCurve.1, yCurve.2, yCurve.3)
    }
    
    var xSettings: AnimationCurve {
        let active = settings.activeSettings
        if let active = active as? SmallMessageSettings {
            return active.curveX
//        } else if let active = active as? BigMessageSettings {
//            return active.curveX
        } else if let active = active as? LinkWithPreviewSettings {
            return active.curveX
        } else if let active = active as? EmojiMessageSettings {
            return active.curveX
        } else if let active = active as? StickerMessageSettings {
            return active.curveX
        } else if let active = active as? VoiceMessageSettings {
            return active.curveX
        } else if let active = active as? VideoMessageSettings {
            return active.curveX
        }
        return AnimationCurve(tuple: (0, 0, 1, 1), delay: 0, duration: 0)
    }
    
    
    
    weak var controllerNode: ChatControllerNode?
    weak var textInput: ChatTextInputPanelNode?
    weak var listView: ChatHistoryListNode?
    weak var accessoryNode: AccessoryPanelNode? // ReplyAccessoryPanelNode // WebpagePreviewAccessoryPanelNode
    
    weak var stickerNode: ChatMediaInputStickerGridItemNode?
    
    func calcGlobalFrame(for node: ListViewItemNode, ignoreDiff: Bool = false) -> CGRect {
        guard let controllerNode = controllerNode else { return node.frame }
        
        let cx = controllerNode.historyNodeContainer.frame.minX
        let ch = controllerNode.historyNodeContainer.frame.height
        
        let lx = controllerNode.historyNode.frame.minX
        
        let diff = controllerNode.inputPanelFrameCurrent.minY - controllerNode.inputPanelFrameTarget.minY
        
        
        
        let nx = node.frame.minX
        let ny = node.frame.minY + (ignoreDiff ? 0 : diff)
        let nw = node.frame.width
        let nh = node.frame.height
        
        return CGRect(x: nx + lx + cx,
                      y: ch - ny - nh,
                      width: nw,
                      height: nh)
    }
    
    var messageType: MessageType?
    
    var durationScale: CGFloat {
        let frames = settings.activeSettings.durationType.rawValue
        return CGFloat(frames) / CGFloat(60)
    }
    
    func animateNode(node: ListViewItemNode, item: ListViewItem?, completion: @escaping () -> Void) {
        stopAnimations()
        guard let _ = textInput, let controllerNode = controllerNode else { completion(); return }
        
        let messageType = getMessageType(node)
        self.messageType = messageType
        print("NODETYPE \(messageType)")
        print("type: \(type(of: node))")
        
        switch messageType {
        case .textSmall:
            settings.activeType = .smallMessage
        case .audio:
            settings.activeType = .voice
        case .video:
            settings.activeType = .video
        case .sticker:
            settings.activeType = .sticker
        case .emoji:
            settings.activeType = .singleEmoji
        case .link:
            settings.activeType = .linkPreview
        }
        
        var shouldIgnoreDiff = false
        if node is ChatMessageInstantVideoItemNode ||
            node is ChatMessageAnimatedStickerItemNode ||
            node is ChatMessageStickerItemNode {
            
            if messageType != .emoji {
                shouldIgnoreDiff = true
            }
        }
        if messageType == .audio {
            shouldIgnoreDiff = true
        }
        listView = controllerNode.historyNode
        
        // disable animation when not at bottom
        guard listView?.isScrollAtBottomPosition == true else { completion(); return }
        
        // save state
        let nodeSuper = node.supernode
        let nodeTransform = node.transform
        let nodeFrame = node.frame
        
        // prepare
//        node.backgroundColor = UIColor.red.withAlphaComponent(0.15)
        node.isHidden = false
        node.transform = CATransform3DIdentity
        node.removeAllAnimations()
        
        // transfer
        node.removeFromSupernode()
        if messageType == .video {
            controllerNode.addSubnode(node)
        } else if messageType == .audio {
            controllerNode.insertSubnode(node, aboveSubnode: controllerNode.historyNodeContainer)
        } else {
            controllerNode.insertSubnode(node, belowSubnode: controllerNode.navigationBarBackroundNode)
        }
        
        // animate
        
        let startFrame: CGRect
        var endFrame = calcGlobalFrame(for: node, ignoreDiff: shouldIgnoreDiff)
        
        
        if stickerNode != nil {
            var frame = controllerNode.inputPanelFrameCurrent
            frame.size.height = controllerNode.frame.height - controllerNode.inputPanelFrameCurrent.minY
            startFrame = frame
        } else if messageType == .emoji {
            
            var frame = controllerNode.inputPanelFrameCurrent
            let h = frame.minY - endFrame.minY
            frame.origin.y -= h
            frame.size.height += h
            
            startFrame = frame
        } else if messageType == .video {
            if let _ = videoFrame {
                let frame = controllerNode.bounds
                startFrame = frame
                endFrame = startFrame
            } else {
                startFrame = .zero
            }
        } else {
            startFrame = controllerNode.inputPanelFrameCurrent
        }
        
        node.animateCustomInsertion()
        
        controllerNode.navigationBar?.isUserInteractionEnabled = false
        listView?.isUserInteractionEnabled = false
        stickerNode = nil
        videoFrame = nil
        tapSource = nil
        self.messageType = nil
        
        animate(node, from: startFrame, to: endFrame, curveX: xSettings, curveY: ySettings, completion: { [weak self] in
            guard let self = self else { return }
            
            
//            node.frame = nodeFrame
            
//            node.backgroundColor = .clear
            node.transform = nodeTransform
            
            node.layer.removeAllAnimations()
//            node.layer.removeAnimationsRecursively()
            node.removeAllAnimations()
            node.pop_removeAllAnimations()
            
            node.removeFromSupernode()
            nodeSuper?.addSubnode(node)
            
            self.nodesAnimating.removeAll()
            
            
            controllerNode.navigationBar?.isUserInteractionEnabled = true
            self.listView?.isUserInteractionEnabled = true
            
            
            completion()
        })
    }
    
    
    func stopAnimations() {
        guard !nodesAnimating.isEmpty else { return }
        
        listView?.removeAllTransitions()
        nodesAnimating.forEach { weakNode in
            guard let node = weakNode.value else { return }
            node.layer.removeAllAnimations()
            if let node = node as? ListViewItemNode {
                node.removeAllAnimations()
            }
        }
        nodesAnimating.removeAll()
        
    }
    
    func animate(_ node: ASDisplayNode, from start: CGRect, to end: CGRect? = nil, removeOnCompletion: Bool = false, curveX: AnimationCurve, curveY: AnimationCurve, completion: (() -> Void)? = nil) {
        nodesAnimating.append(WeakRef(value: node))
        var startFrame = start
        let endFrame = end ?? node.frame
        
//        let durationX: Double = Double(3)
//        let delayX: Double = Double(0)
//        let durationY: Double = Double(3)
//        let delayY: Double = Double(0)
        let ds = durationScale
        let durationX: Double = Double(curveX.duration) * Double(durationScale)
        let delayX: Double = Double(curveX.delay) * Double(durationScale)
        let durationY: Double = Double(curveY.duration) * Double(durationScale)
        let delayY: Double = Double(curveY.delay) * Double(durationScale)
        
        let curX = CAMediaTimingFunction(controlPoints: curveX.tuple.0, curveX.tuple.1, curveX.tuple.2, curveX.tuple.3)
        let curY = CAMediaTimingFunction(controlPoints: curveY.tuple.0, curveY.tuple.1, curveY.tuple.2, curveY.tuple.3)
        
        var completed = 4
        
        node.layer.animatePositionX(from: startFrame.midX, to: endFrame.midX, duration: durationX, delay: delayX, timingFunction: "", mediaTimingFunction: curX, removeOnCompletion: removeOnCompletion, additive: false, force: true) { [weak self] _ in
            
            completed -= 1
            if completed <= 0 {
                self?.nodesAnimating.removeAll(where: { $0.value === node })
                completion?()
            }
        }
        node.layer.animatePositionY(from: startFrame.midY, to: endFrame.midY, duration: durationY, delay: delayY, timingFunction: "", mediaTimingFunction: curY, removeOnCompletion: removeOnCompletion, additive: false, force: true) { [weak self] _ in
            
            completed -= 1
            if completed <= 0 {
                self?.nodesAnimating.removeAll(where: { $0.value === node })
                completion?()
            }
        }
        
        node.layer.animateBoundsW(from: startFrame.width, to: endFrame.width, duration: durationX, delay: delayX, timingFunction: "", mediaTimingFunction: curX, removeOnCompletion: removeOnCompletion, additive: false, force: true) { [weak self] _ in
            
            completed -= 1
            if completed <= 0 {
                self?.nodesAnimating.removeAll(where: { $0.value === node })
                completion?()
            }
        }
        node.layer.animateBoundsH(from: startFrame.height, to: endFrame.height, duration: durationY, delay: delayY, timingFunction: "", mediaTimingFunction: curY, removeOnCompletion: removeOnCompletion, additive: false, force: true) { [weak self] _ in
            
            completed -= 1
            if completed <= 0 {
                self?.nodesAnimating.removeAll(where: { $0.value === node })
                completion?()
            }
        }
    }
    
    
    func animate(_ node: ASDisplayNode, from start: CGRect, to end: CGRect? = nil, removeOnCompletion: Bool = false, curveX: AnimationCurve, curveY: AnimationCurve, curveScale: AnimationCurve, completion: (() -> Void)? = nil) {
        
        nodesAnimating.append(WeakRef(value: node))
        var startFrame = start
        let endFrame = end ?? node.frame
        
        
        let durationX: Double = Double(curveX.duration) * Double(durationScale)
        let delayX: Double = Double(curveX.delay) * Double(durationScale)
        let durationY: Double = Double(curveY.duration) * Double(durationScale)
        let delayY: Double = Double(curveY.delay) * Double(durationScale)
        let durationScale: Double = Double(curveScale.duration) * Double(self.durationScale)
        let delayScale: Double = Double(curveScale.delay) * Double(durationScale)
        
        
//        let durationX: Double = Double(3)//Double(curveX.duration)
//        let delayX: Double = Double(0)//Double(curveX.delay)
//        let durationY: Double = Double(3)//Double(curveY.duration)
//        let delayY: Double = Double(0)//Double(curveY.delay)
//        let durationScale: Double = Double(3)//Double(curveScale.duration)
//        let delayScale: Double = Double(0)//Double(curveScale.delay)
        
        let curX = CAMediaTimingFunction(controlPoints: curveX.tuple.0, curveX.tuple.1, curveX.tuple.2, curveX.tuple.3)
        let curY = CAMediaTimingFunction(controlPoints: curveY.tuple.0, curveY.tuple.1, curveY.tuple.2, curveY.tuple.3)
        let curScale = CAMediaTimingFunction(controlPoints: curveScale.tuple.0, curveScale.tuple.1, curveScale.tuple.2, curveScale.tuple.3)
        
        var completed = 4
        
        node.layer.animatePositionX(from: startFrame.midX, to: endFrame.midX, duration: durationX, delay: delayX, timingFunction: "", mediaTimingFunction: curX, removeOnCompletion: removeOnCompletion, additive: false, force: true) { [weak self] _ in
            
            completed -= 1
            if completed <= 0 {
                self?.nodesAnimating.removeAll(where: { $0.value === node })
                completion?()
            }
        }
        node.layer.animatePositionY(from: startFrame.midY, to: endFrame.midY, duration: durationY, delay: delayY, timingFunction: "", mediaTimingFunction: curY, removeOnCompletion: removeOnCompletion, additive: false, force: true) { [weak self] _ in
            
            completed -= 1
            if completed <= 0 {
                self?.nodesAnimating.removeAll(where: { $0.value === node })
                completion?()
            }
        }
        node.layer.animateBoundsW(from: startFrame.width, to: endFrame.width, duration: durationScale, delay: delayScale, timingFunction: "", mediaTimingFunction: curScale, removeOnCompletion: removeOnCompletion, additive: false, force: true) { [weak self] _ in
            
            completed -= 1
            if completed <= 0 {
                self?.nodesAnimating.removeAll(where: { $0.value === node })
                completion?()
            }
        }
        node.layer.animateBoundsH(from: startFrame.height, to: endFrame.height, duration: durationScale, delay: delayScale, timingFunction: "", mediaTimingFunction: curScale, removeOnCompletion: removeOnCompletion, additive: false, force: true) { [weak self] _ in
            
            completed -= 1
            if completed <= 0 {
                self?.nodesAnimating.removeAll(where: { $0.value === node })
                completion?()
            }
        }
    }
    
    func animate(_ node: ASDisplayNode, fromAlpha: CGFloat, toAlpha: CGFloat, curve: AnimationCurve, completion: (() -> Void)? = nil) {
        nodesAnimating.append(WeakRef(value: node))
        node.layer.animateAlpha(from: fromAlpha,
                                to: toAlpha,
                                duration: TimeInterval(curve.duration) * TimeInterval(durationScale),
                                delay: TimeInterval(curve.delay) * TimeInterval(durationScale),
                                timingFunction: "",
                                mediaTimingFunction: CAMediaTimingFunction(controlPoints: curve.tuple.0, curve.tuple.1, curve.tuple.2, curve.tuple.3),
                                completion: { [weak self] _ in
                                    
            self?.nodesAnimating.removeAll(where: { $0.value === node })
            completion?()
        })
    }
    
    func animate(_ node: ASDisplayNode, fromColor: UIColor, toColor: UIColor? = nil) {
        nodesAnimating.append(WeakRef(value: node))
        
        let animation = CABasicAnimation(keyPath: "foregroundColor")
        animation.beginTime = CACurrentMediaTime() + yDelay
        animation.fromValue = fromColor.cgColor
        animation.toValue = toColor?.cgColor ?? node.borderColor
        animation.timingFunction = curveFunctionY//curveFunction
        
        animation.duration = yDuration
        node.layer.add(animation, forKey: "foregroundColor")
    }
    
    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        guard flag else { return }
    }
    
    
    private func getMessageType(_ node: ListViewItemNode) -> MessageType {
        if node is ChatMessageInstantVideoItemNode {
            return .video
        } else if let tapSource = tapSource, tapSource == .sticker {
            return .sticker
        } else if node is ChatMessageStickerItemNode || node is ChatMessageAnimatedStickerItemNode {
//            if let tapSource = tapSource, tapSource == .sendButton {
                return .emoji
//            }
//            return .sticker
        } else if accessoryNode is WebpagePreviewAccessoryPanelNode {
            return .link
        } else if let n = node as? ChatMessageBubbleItemNode {
            // check if text is big
            // check if is link
            
            
            if let tapSource = tapSource {
                if tapSource == .mediaButton {
                    return .audio
                }
            }
        }
        
        return .textSmall
    }
    
    
}


class WeakRef<T> where T: AnyObject {

    private(set) weak var value: T?

    init(value: T?) {
        self.value = value
    }
}


public extension ASDisplayNode {
    
    @objc open func animateCustomInsertion() {}
}


extension CALayer {
    
    func removeAnimationsRecursively() {
        removeAllAnimations()
        sublayers?.forEach {
            $0.removeAnimationsRecursively()
        }
    }
}
