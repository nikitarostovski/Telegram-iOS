import Foundation
import UIKit
import Display
import AsyncDisplayKit
import MetalKit
import simd

private let motionAmount: CGFloat = 32.0

public typealias AnimatedBackgroundPoint = (color: UIColor, point: CGPoint)
public typealias AnimatedBackgroundState = (AnimatedBackgroundPoint,
                                            AnimatedBackgroundPoint,
                                            AnimatedBackgroundPoint,
                                            AnimatedBackgroundPoint)



public final class WallpaperBackgroundNode: ASDisplayNode {
    fileprivate let contentNode: ContentNode
    
    public var animationCurve: (Float, Float, Float, Float) = (0, 0, 1, 1)
    public var animationDelay: TimeInterval = 0
    public var animationDuration: TimeInterval = 1
    
    public var color1: UIColor = .red
    public var color2: UIColor = .red
    public var color3: UIColor = .red
    public var color4: UIColor = .red
    
    public var motionEnabled: Bool = false {
        didSet {
            if oldValue != self.motionEnabled {
                if self.motionEnabled {
                    let horizontal = UIInterpolatingMotionEffect(keyPath: "center.x", type: .tiltAlongHorizontalAxis)
                    horizontal.minimumRelativeValue = motionAmount
                    horizontal.maximumRelativeValue = -motionAmount
                    
                    let vertical = UIInterpolatingMotionEffect(keyPath: "center.y", type: .tiltAlongVerticalAxis)
                    vertical.minimumRelativeValue = motionAmount
                    vertical.maximumRelativeValue = -motionAmount
                    
                    let group = UIMotionEffectGroup()
                    group.motionEffects = [horizontal, vertical]
                    self.contentNode.view.addMotionEffect(group)
                } else {
                    for effect in self.contentNode.view.motionEffects {
                        self.contentNode.view.removeMotionEffect(effect)
                    }
                }
                if !self.frame.isEmpty {
                    self.updateScale()
                }
            }
        }
    }
        
    public var image: UIImage? {
        didSet {
            self.contentNode.updateContent(image: self.image?.cgImage,
                                           colors: self.animatedGradientColors)
        }
    }
    
    public var animatedGradientColors: (UInt32, UInt32, UInt32, UInt32)? {
        didSet {
            self.contentNode.updateContent(image: self.image?.cgImage,
                                           colors: self.animatedGradientColors)
        }
    }
    
    public var rotation: CGFloat = 0.0 {
        didSet {
            var fromValue: CGFloat = 0.0
            if let value = (self.layer.value(forKeyPath: "transform.rotation.z") as? NSNumber)?.floatValue {
                fromValue = CGFloat(value)
            }
            self.contentNode.layer.transform = CATransform3DMakeRotation(self.rotation, 0.0, 0.0, 1.0)
            self.contentNode.layer.animateRotation(from: fromValue, to: self.rotation, duration: 0.3)
        }
    }
    
    public var imageContentMode: UIView.ContentMode {
        didSet {
            self.contentNode.contentMode = self.imageContentMode
        }
    }
    
    func updateScale() {
        if self.motionEnabled {
            let scale = (self.frame.width + motionAmount * 2.0) / self.frame.width
            self.contentNode.transform = CATransform3DMakeScale(scale, scale, 1.0)
        } else {
            self.contentNode.transform = CATransform3DIdentity
        }
    }
    
    public override init() {
        self.imageContentMode = .scaleAspectFill
        
        self.contentNode = ContentNode()
        self.contentNode.contentMode = self.imageContentMode
        
        super.init()
        
        self.clipsToBounds = true
        self.contentNode.frame = self.bounds
        
        self.addSubnode(self.contentNode)
    }
    
    public func updateData() {
        contentNode.animationDelay = animationDelay
        contentNode.animationDuration = animationDuration
        contentNode.animationCurve = animationCurve
        contentNode.color1 = color1
        contentNode.color2 = color2
        contentNode.color3 = color3
        contentNode.color4 = color4
    }
    
    public func animate() {
        contentNode.animate()
    }
    
    public func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        let isFirstLayout = self.contentNode.frame.isEmpty
        transition.updatePosition(node: self.contentNode, position: CGPoint(x: size.width / 2.0, y: size.height / 2.0))
        transition.updateBounds(node: self.contentNode, bounds: CGRect(origin: CGPoint(), size: size))
        
        if isFirstLayout && !self.frame.isEmpty {
            self.updateScale()
        }
    }
}


fileprivate class ContentNode: ASDisplayNode {
    
    public var animationCurve: (Float, Float, Float, Float) = (0, 0, 1, 1)
    public var animationDelay: TimeInterval = 0
    public var animationDuration: TimeInterval = 1
    
    public var color1: UIColor = .red
    public var color2: UIColor = .red
    public var color3: UIColor = .red
    public var color4: UIColor = .red
    
    var background: BackgroundView?
    
    override func layout() {
        super.layout()
        
        if let background = background {
            background.frame = self.bounds
        }
    }
    
    func updateContent(image: CGImage?, colors: (UInt32, UInt32, UInt32, UInt32)?) {
        if let image = image {
            self.contents = image
            removeMetalViewIfNeeded()
        } else if let colors = colors {
            self.contents = nil
            configureMetalViewIfNeeded()
        }
    }
    
    func animate() {
        background?.animate()
    }
    
    private func configureMetalViewIfNeeded() {
        removeMetalViewIfNeeded()
        let v = BackgroundView(frame: bounds)
        
        v.animationDelay = animationDelay
        v.animationDuration = animationDuration
        v.animationCurve = animationCurve
        v.color1 = color1
        v.color2 = color2
        v.color3 = color3
        v.color4 = color4
        
        self.view.addSubview(v)
        self.background = v
    }
    
    private func removeMetalViewIfNeeded() {
        guard let background = background else { return }
        background.removeFromSuperview()
        self.background = nil
    }
}
