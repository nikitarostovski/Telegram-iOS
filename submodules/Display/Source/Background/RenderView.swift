//
//  RenderView.swift
//  ShaderTest
//
//  Created by Nikita Rostovskii on 22.01.2021.
//

import CoreImage
import UIKit

public class BackgroundView: UIView, BackgroundDataSource {
    
    public var animationDelay: TimeInterval = 0
    public var animationDuration: TimeInterval = 0.5
    public var animationCurve: (Float, Float, Float, Float) = (0.6, 0.04, 0.98, 0.335)
    
    var blurEnabled: Bool {
        get {
            v?.blurEnabled ?? false
        }
        set {
            v?.blurEnabled = newValue
        }
    }
    
    var turbulentDisplacementEnabled: Bool {
        get {
            v?.turbulentDisplacementEnabled ?? false
        }
        set {
            v?.turbulentDisplacementEnabled = newValue
        }
    }
    
    public var color1: UIColor = UIColor.red {
        didSet {
            v?.reload()
        }
    }
    public var color2: UIColor = UIColor.green {
        didSet {
            v?.reload()
        }
    }
    public var color3: UIColor = UIColor.blue {
        didSet {
            v?.reload()
        }
    }
    public var color4: UIColor = UIColor.yellow {
        didSet {
            v?.reload()
        }
    }
    
    private let p1a = CGPoint(x: 0.35, y: 0.25)
    private let p1b = CGPoint(x: 0.82, y: 0.09)
    private let p1c = CGPoint(x: 0.65, y: 0.75)
    private let p1d = CGPoint(x: 0.18, y: 0.92)
    
    private let p2a = CGPoint(x: 0.25, y: 0.6)
    private let p2b = CGPoint(x: 0.6, y: 0.15)
    private let p2c = CGPoint(x: 0.75, y: 0.42)
    private let p2d = CGPoint(x: 0.42, y: 0.84)
    
    private var positionIndex = 0
    private let positions: [(CGPoint, CGPoint, CGPoint, CGPoint)]!
    
    private var currentPositions: (CGPoint, CGPoint, CGPoint, CGPoint)?
    
    var points: [VertexPoint] {
        guard let curPos = currentPositions else { return [] }
        return [
            VertexPoint(x: Double(curPos.0.x), y: Double(curPos.0.y), color: color1),
            VertexPoint(x: Double(curPos.1.x), y: Double(curPos.1.y), color: color2),
            VertexPoint(x: Double(curPos.2.x), y: Double(curPos.2.y), color: color3),
            VertexPoint(x: Double(curPos.3.x), y: Double(curPos.3.y), color: color4)
        ]
    }
    
    private lazy var animator: AnimationManager = {
        AnimationManager(superlayer: layer)
    }()
    
    fileprivate lazy var v: RenderView? = {
        RenderView(dataSource: self)
    }()
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        v?.frame = bounds
        v?.reload()
    }
    
    override init(frame: CGRect) {
        self.positions = [
            (p1a, p1b, p1c, p1d),
            (p2a, p2b, p2c, p2d),
            (p1d, p1a, p1b, p1c),
            (p2d, p2a, p2b, p2c),
            (p1c, p1d, p1a, p1b),
            (p2c, p2d, p2a, p2b),
            (p1b, p1c, p1d, p1a),
            (p2b, p2c, p2d, p2a),
       ]
        self.currentPositions = positions.first
        super.init(frame: frame)
        if let v = v {
            addSubview(v)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private (set) var isAnimating = false
    
    @objc public func animate() {
        guard !isAnimating else { return }
        isAnimating = true
        
        let oldPositions = positions[positionIndex]
        positionIndex -= 1
        if positionIndex < 0 {
            positionIndex = positions.count - 1
        }
        let newPositions = positions[positionIndex]
        
        animator.start(delay: animationDelay, duration: animationDuration, curve: animationCurve) { [weak self] progress in
            guard let self = self else { return }
            
            func interpolate(from: CGPoint, to: CGPoint, progress: Float) -> CGPoint {
                let startX = Double(from.x)
                let startY = Double(from.y)
                let endX = Double(to.x)
                let endY = Double(to.y)
                
                return CGPoint(x: startX + (endX - startX) * Double(progress), y: startY + (endY - startY) * Double(progress))
            }
            
            let p1 = interpolate(from: oldPositions.0, to: newPositions.0, progress: progress)
            let p2 = interpolate(from: oldPositions.1, to: newPositions.1, progress: progress)
            let p3 = interpolate(from: oldPositions.2, to: newPositions.2, progress: progress)
            let p4 = interpolate(from: oldPositions.3, to: newPositions.3, progress: progress)
            
            self.currentPositions = (p1, p2, p3, p4)
            
            self.v?.reload()
        } completion: { [weak self] in
            self?.isAnimating = false
        }
    }
}


class AnimationManager {
    
    private var displayLink: CADisplayLink?
    
    private var completion: (() -> Void)?
    private var animation: ((Float) -> Void)?
    
    private let layer = CALayer()
    
    private var lastValue: CGFloat?
    
    private weak var superlayer: CALayer?
    
    init(superlayer: CALayer) {
        self.superlayer = superlayer
    }
    
    func start(delay: TimeInterval, duration: TimeInterval, curve: (Float, Float, Float, Float), animation: ((Float) -> Void)? = nil, completion: (() -> Void)? = nil) {
        
        superlayer?.addSublayer(layer)
        
        self.animation = animation
        self.completion = completion
        
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(Int(delay * 1000))) {
            CATransaction.begin()
            
            let basicAnimation = CABasicAnimation(keyPath: "bounds.origin.x")
            basicAnimation.duration = duration
            basicAnimation.isRemovedOnCompletion = false
            basicAnimation.timingFunction = CAMediaTimingFunction(controlPoints: curve.0, curve.1, curve.2, curve.3)
            basicAnimation.fromValue = 0.0
            basicAnimation.toValue = 1.0
            
            CATransaction.setCompletionBlock { [weak self] in
                self?.stopDisplayLink()
                self?.layer.removeAllAnimations()
                self?.layer.removeFromSuperlayer()
                DispatchQueue.main.async {
                    if (self?.lastValue ?? 0) != 1 {
                        self?.animation?(Float(1))
                    }
                    self?.completion?()
                    self?.lastValue = nil
                }
            }

            self.layer.add(basicAnimation, forKey: "evaluatorAnimation")
            CATransaction.commit()
            
            self.startDisplayLink()
        }
    }
    
    private func startDisplayLink() {
        stopDisplayLink()

        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkFire))
        displayLink?.add(to: .main, forMode: .common)
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc func displayLinkFire() {
        let layer = self.layer.presentation() ?? self.layer
        var value = layer.bounds.origin.x
        if let lastValue = lastValue, value <= lastValue {
           value = 1
        }
        lastValue = value
        DispatchQueue.main.async {
            self.animation?(Float(value))
        }
    }
}



protocol BackgroundDataSource: class {
    var points: [VertexPoint] { get }
}

public struct VertexPoint: Hashable {

    public var x: Double
    public var y: Double
    public let color: UIColor

    public init(x: Double, y: Double, color: UIColor) {
        self.x = x
        self.y = y
        self.color = color
    }
}

public class RenderView: UIView {
    
    private let imageMaxSize: CGFloat = 32
    private let blurRadius: CGFloat = 3
    
    var turbulentDisplacementEnabled = true
    var blurEnabled = true
    
    private weak var dataSource: BackgroundDataSource?
    private var imageView: UIImageView
    
    
    private var imageSize: CGSize = .zero
    
    init?(dataSource: BackgroundDataSource) {
        self.dataSource = dataSource
        self.imageView = UIImageView()
        super.init(frame: .zero)
        
        self.imageView.contentMode = .scaleToFill
        
        updateSizes()
        
        addSubview(imageView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = bounds
        updateSizes()
    }
    
    private func updateSizes() {
        let aspect = UIScreen.main.bounds.width / UIScreen.main.bounds.height
        imageSize = CGSize(width: imageMaxSize * aspect,
                           height: imageMaxSize)
    }
    
    // render
    let context = CIContext()
    
    lazy var queue: OperationQueue = {
       let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    
    
    func reload() {
        queue.cancelAllOperations()
        queue.addOperation { [weak self] in
            guard let self = self else { return }
            guard var ciimage = self.makeGradient() else { return }
            var extent = ciimage.extent

//            if self.turbulentDisplacementEnabled {
//                if let cgImage = self.context.createCGImage(ciimage, from: extent) {
//                    let imageScale: CGFloat = 2
//                    let uiimage = UIImage(cgImage: cgImage)
//                    let newSize = CGSize(width: extent.width * imageScale, height: extent.height * imageScale)
//                    let scaledImage = UIImage.resize(image: uiimage, targetSize: newSize)
//                    ciimage = CIImage(image: scaledImage)!
//                }
//            }
//            extent = ciimage.extent
            
            if self.turbulentDisplacementEnabled {
                let displacementScale: CGFloat = 30
                let displacement = CIImage(image: self.displacementImage)!
                let twirl = CIFilter(name: "CIDisplacementDistortion")
                twirl?.setValue(ciimage, forKey: kCIInputImageKey)
                twirl?.setValue(displacementScale, forKey: kCIInputScaleKey)
                twirl?.setValue(displacement, forKey: "inputDisplacementImage")
                
                ciimage = twirl?.value(forKey: kCIOutputImageKey) as? CIImage ?? ciimage
            }
            
            if self.blurEnabled {
                ciimage = ciimage.clampedToExtent()

                let blur = CIFilter(name: "CIGaussianBlur")
                blur?.setValue(ciimage, forKey: kCIInputImageKey)
                blur?.setValue(self.blurRadius, forKey: "inputRadius")
                ciimage = blur?.value(forKey: kCIOutputImageKey) as? CIImage ?? ciimage
            }
            
            

            guard let cgImage = self.context.createCGImage(ciimage, from: extent) else { return }
            let image = UIImage(cgImage: cgImage)

            DispatchQueue.main.async {
                self.imageView.image = image
            }
        }
    }
    
    private func makeGradient() -> CIImage? {
        
        guard let points = dataSource?.points, points.count > 3 else { return nil }
        
        let p1 = CGPoint(x: CGFloat(points[0].x) * imageSize.width, y: CGFloat(1 - points[0].y) * imageSize.height)
        let p2 = CGPoint(x: CGFloat(points[1].x) * imageSize.width, y: CGFloat(1 - points[1].y) * imageSize.height)
        let p3 = CGPoint(x: CGFloat(points[2].x) * imageSize.width, y: CGFloat(1 - points[2].y) * imageSize.height)
        let p4 = CGPoint(x: CGFloat(points[3].x) * imageSize.width, y: CGFloat(1 - points[3].y) * imageSize.height)
        
        let colorPoints: [ColorPoint] = [
            ColorPoint(point: p1, color: points[0].color),
            ColorPoint(point: p2, color: points[1].color),
            ColorPoint(point: p3, color: points[2].color),
            ColorPoint(point: p4, color: points[3].color)
        ]
        
        if let cgimage = makeImage(from: colorPoints) {
            return CIImage(cgImage: cgimage)
        }
        
        return nil
    }
    
    fileprivate func makeImage(from colorPoints: [ColorPoint]) -> CGImage? {
        
        func getProjectionDistance(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> CGPoint {
            let k2 = b.x * b.x - b.x * a.x + b.y * b.y - b.y * a.y
            let k1 = a.x * a.x - b.x * a.x + a.y * a.y - b.y * a.y
            let ab2 = (a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)
            let kcom = (c.x * (a.x - b.x) + c.y * (a.y - b.y))
            let d1 = (k1 - kcom) / ab2
            let d2 = (k2 + kcom) / ab2
            return CGPoint(x: d1, y: d2)
        }

        func limit01(_ value: CGFloat) -> CGFloat {
            if value < 0 { return 0 }
            if value > 1 { return 1 }
            return value
        }

        func getWeightedColorMix(_ points: [ColorPoint], _ ratios: [CGFloat]) -> PixelData {
            var r: UInt8 = 0
            var g: UInt8 = 0
            var b: UInt8 = 0
            for i in 0 ..< points.count {
                r += UInt8(CGFloat(points[i].color.r) * ratios[i])
                g += UInt8(CGFloat(points[i].color.g) * ratios[i])
                b += UInt8(CGFloat(points[i].color.b) * ratios[i])
            }
            return PixelData(a: UInt8(255), r: r, g: g, b: b)
        }

        func getGeometricColorMix(_ p: CGPoint, _ points: [ColorPoint]) -> PixelData {
            var colorRatios = points.map { _ in
                CGFloat(1)
            }
            
            for ind1 in 0 ..< points.count {
                for ind2 in 0 ..< points.count {
                    guard ind1 != ind2 else { continue }
                    
                    let d = getProjectionDistance(points[ind1].point, points[ind2].point, p)
                    colorRatios[ind1] *= limit01(d.y)
                }
            }
          
            var totalRatiosSum: CGFloat = 0
            for i in 0 ..< colorRatios.count {
              totalRatiosSum += colorRatios[i]
            }
            for i in 0 ..< colorRatios.count {
              colorRatios[i] /= totalRatiosSum
            }
            return getWeightedColorMix(points, colorRatios)
        }
        
        var pixelData = [PixelData]()
        for y in 0 ..< Int(imageSize.height) {
            for x in 0 ..< Int(imageSize.width) {
                let mixColor = getGeometricColorMix(CGPoint(x: x, y: y), colorPoints)
                pixelData.append(mixColor)
            }
        }
        return CGImage.make(pixels: pixelData, width: Int(imageSize.width), height: Int(imageSize.height))
    }
    
    lazy var displacementImage: UIImage = {
        let base64 = "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b2wAAAAAAEJja2dPYmpjAAAAAQAAAAAAAFJHQkMAAAADAAAAAFJkICBkb3ViQG/gAAAAAAAAAAAAR3JuIGRvdWJAb+AAAAAAAAAAAABCbCAgZG91YkBv4AAAAAAAAAAAAEJyZFRVbnRGI1JsdAAAAAAAAAAAAAAAAEJsZCBVbnRGI1JsdAAAAAAAAAAAAAAAAFJzbHRVbnRGI1B4bEBSAAAAAAAAAAAACnZlY3RvckRhdGFib29sAQAAAABQZ1BzZW51bQAAAABQZ1BzAAAAAFBnUEMAAAAATGVmdFVudEYjUmx0AAAAAAAAAAAAAAAAVG9wIFVudEYjUmx0AAAAAAAAAAAAAAAAU2NsIFVudEYjUHJjQFkAAAAAAAAAAAAQY3JvcFdoZW5QcmludGluZ2Jvb2wAAAAADmNyb3BSZWN0Qm90dG9tbG9uZwAAAAAAAAAMY3JvcFJlY3RMZWZ0bG9uZwAAAAAAAAANY3JvcFJlY3RSaWdodGxvbmcAAAAAAAAAC2Nyb3BSZWN0VG9wbG9uZwAAAAAAOEJJTQPtAAAAAAAQAEgAAAABAAIASAAAAAEAAjhCSU0EJgAAAAAADgAAAAAAAAAAAAA/gAAAOEJJTQQNAAAAAAAEAAAAHjhCSU0EGQAAAAAABAAAAB44QklNA/MAAAAAAAkAAAAAAAAAAAEAOEJJTScQAAAAAAAKAAEAAAAAAAAAAjhCSU0D9QAAAAAASAAvZmYAAQBsZmYABgAAAAAAAQAvZmYAAQChmZoABgAAAAAAAQAyAAAAAQBaAAAABgAAAAAAAQA1AAAAAQAtAAAABgAAAAAAAThCSU0D+AAAAAAAcAAA/////////////////////////////wPoAAAAAP////////////////////////////8D6AAAAAD/////////////////////////////A+gAAAAA/////////////////////////////wPoAAA4QklNBAAAAAAAAAIAAzhCSU0EAgAAAAAACAAAAAAAAAAAOEJJTQQwAAAAAAAEAQEBAThCSU0ELQAAAAAABgABAAAABDhCSU0ECAAAAAAAEAAAAAEAAAJAAAACQAAAAAA4QklNBB4AAAAAAAQAAAAAOEJJTQQaAAAAAANPAAAABgAAAAAAAAAAAAAAgAAAAIAAAAANAHQAdQBy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gSU5eRW/JeWOBbPdV20V9PsDA6ZUupZeS126kLOxKM7qGa02e1jTqkp//9k4QklNBCEAAAAAAFcAAAABAQAAAA8AQQBkAG8AYgBlACAAUABoAG8AdABvAHMAaABvAHAAAAAUAEEAZABvAGIAZQAgAFAAaABvAHQAbwBzAGgAbwBwACAAMgAwADIAMAAAAAEAOEJJTQQGAAAAAAAHAAQBAQABAQD/4Q5FaHR0cDovL25zLmFkb2JlLmNvbS94YXAvMS4wLwA8P3hwYWNrZXQgYmVnaW49Iu+7vyIgaWQ9Ilc1TTBNcENlaGlIenJlU3pOVGN6a2M5ZCI/PiA8eDp4bXBtZXRhIHhtbG5zOng9ImFkb2JlOm5zOm1ldGEvIiB4OnhtcHRrPSJBZG9iZSBYTVAgQ29yZSA1LjYtYzE0OCA3OS4xNjQwMzYsIDIwMTkvMDgvMTMtMDE6MDY6NTcgICAgICAgICI+IDxyZGY6UkRGIHhtbG5zOnJkZj0iaHR0cDovL3d3dy53My5vcmcvMTk5OS8wMi8yMi1yZGYtc3ludGF4LW5zIyI+IDxyZGY6RGVzY3JpcHRpb24gcmRmOmFib3V0PSIiIHhtbG5zOnhtcE1NPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvbW0vIiB4bWxuczpzdEV2dD0iaHR0cDovL25zLmFkb2JlLmNvbS94YXAvMS4wL3NUeXBlL1Jlc291cmNlRXZlbnQjIiB4bWxuczpkYz0iaHR0cDovL3B1cmwub3JnL2RjL2VsZW1lbnRzLzEuMS8iIHhtbG5zOnBob3Rvc2hvcD0iaHR0cDovL25zLmFkb2JlLmNvbS9waG90b3Nob3AvMS4wLyIgeG1sbnM6eG1wPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvIiB4bXBNTTpEb2N1bWVudElEPSJhZG9iZTpkb2NpZDpwaG90b3Nob3A6NjQzOTEzZDMtMjNhZS1lZjRlLWE4ZmItNzRlNWY2MjZjYTVkIiB4bXBNTTpJbnN0YW5jZUlEPSJ4bXAuaWlkOmU0NTZiYzA4LWU3NDgtNDA4Yy1iNGFkLWJjYzQ5YjUxZDQ1OCIgeG1wTU06T3JpZ2luYWxEb2N1bWVudElEPSIwNDc4M0VBM0YxRjREQzBCOTY1RkQ0RTA2NTQ4RDlCNiIgZGM6Zm9ybWF0PSJpbWFnZS9qcGVnIiBwaG90b3Nob3A6Q29sb3JNb2RlPSIzIiBwaG90b3Nob3A6SUNDUHJvZmlsZT0iIiB4bXA6Q3JlYXRlRGF0ZT0iMjAyMS0wMS0zMFQxNDowMjo0MiswMzowMCIgeG1wOk1vZGlmeURhdGU9IjIwMjEtMDEtMzBUMTU6NTQ6MjcrMDM6MDAiIHhtcDpNZXRhZGF0YURhdGU9IjIwMjEtMDEtMzBUMTU6NTQ6MjcrMDM6MDAiPiA8eG1wTU06SGlzdG9yeT4gPHJkZjpTZXE+IDxyZGY6bGkgc3RFdnQ6YWN0aW9uPSJzYXZlZCIgc3RFdnQ6aW5zdGFuY2VJRD0ieG1wLmlpZDpjYTRlNDg4Ni0zMDkxLTRkOGYtOGM5ZS01NDBiODJmNTU1YzAiIHN0RXZ0OndoZW49IjIwMjEtMDEtMzBUMTU6NTQ6MjcrMDM6MDAiIHN0RXZ0OnNvZnR3YXJlQWdlbnQ9IkFkb2JlIFBob3Rvc2hvcCAyMS4wIChNYWNpbnRvc2gpIiBzdEV2dDpjaGFuZ2VkPSIvIi8+IDxyZGY6bGkgc3RFdnQ6YWN0aW9uPSJzYXZlZCIgc3RFdnQ6aW5zdGFuY2VJRD0ieG1wLmlpZDplNDU2YmMwOC1lNzQ4LTQwOGMtYjRhZC1iY2M0OWI1MWQ0NTgiIHN0RXZ0OndoZW49IjIwMjEtMDEtMzBUMTU6NTQ6MjcrMDM6MDAiIHN0RXZ0OnNvZnR3YXJlQWdlbnQ9IkFkb2JlIFBob3Rvc2hvcCAyMS4wIChNYWNpbnRvc2gpIiBzdEV2dDpjaGFuZ2VkPSIvIi8+IDwvcmRmOlNlcT4gPC94bXBNTTpIaXN0b3J5PiA8cGhvdG9zaG9wOkRvY3VtZW50QW5jZXN0b3JzPiA8cmRmOkJhZz4gPHJkZjpsaT4wNDc4M0VBM0YxRjREQzBCOTY1RkQ0RTA2NTQ4RDlCNjwvcmRmOmxpPiA8L3JkZjpCYWc+IDwvcGhvdG9zaG9wOkRvY3VtZW50QW5jZXN0b3JzPiA8L3JkZjpEZXNjcmlwdGlvbj4gPC9yZGY6UkRGPiA8L3g6eG1wbWV0YT4gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg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"
        let dataDecoded: Data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters)!
        return UIImage(data: dataDecoded)!
    }()
}


fileprivate struct ColorPoint {
    var x: CGFloat
    var y: CGFloat
    var color: PixelData
    
    var point: CGPoint {
        CGPoint(x: x, y: y)
    }
    
    init(point: CGPoint, color: UIColor) {
        self.x = point.x
        self.y = point.y
        self.color = PixelData(color)
    }
}

fileprivate struct PixelData {
    var a: UInt8
    var r: UInt8
    var g: UInt8
    var b: UInt8
    
    init(a: UInt8, r: UInt8, g: UInt8, b: UInt8) {
        self.a = a
        self.r = r
        self.g = g
        self.b = b
    }
    
    init(_ color: UIColor) {
        let rgba = color.getRGBA()
        self.r = UInt8(rgba.0 * 255)
        self.g = UInt8(rgba.1 * 255)
        self.b = UInt8(rgba.2 * 255)
        self.a = UInt8(255)
    }
}

fileprivate extension CGImage {
    
    static func make(pixels: [PixelData], width: Int, height: Int) -> CGImage? {
        guard width > 0 && height > 0, pixels.count == width * height else { return nil }
        var data = pixels
        guard let providerRef = CGDataProvider(data: Data(bytes: &data, count: data.count * MemoryLayout<PixelData>.size) as CFData)
            else { return nil }
        
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * MemoryLayout<PixelData>.size,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue),
            provider: providerRef,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent)
    }
}



extension UIColor {

    func getRGBA() -> (CGFloat, CGFloat, CGFloat) {
        var fRed : CGFloat = 0
        var fGreen : CGFloat = 0
        var fBlue : CGFloat = 0
        var fAlpha: CGFloat = 0
        if self.getRed(&fRed, green: &fGreen, blue: &fBlue, alpha: &fAlpha) {
            let iRed = fRed
            let iGreen = fGreen
            let iBlue = fBlue
            let iAlpha = fAlpha

            return (iRed, iGreen, iBlue)
        } else {
            return (0, 0, 0)
        }
    }
}


extension UIImage {
    
    class func resize(image: UIImage, targetSize: CGSize) -> UIImage {
            let size = image.size
            
            let widthRatio  = targetSize.width  / image.size.width
            let heightRatio = targetSize.height / image.size.height
            
            var newSize: CGSize
            if widthRatio > heightRatio {
                newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
            } else {
                newSize = CGSize(width: size.width * widthRatio,  height: size.height * widthRatio)
            }
            
            let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
            
            UIGraphicsBeginImageContextWithOptions(newSize, false, 0)
            image.draw(in: rect)
            let newImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            return newImage!
        }
    
    func resizedImage(size newSize: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0)
        defer { UIGraphicsEndImageContext() }

        draw(in: CGRect(origin: .zero, size: newSize))
        return UIGraphicsGetImageFromCurrentImageContext()
      }
}
