//
//  MediaTimingFunctionEditControl.swift
//  ShaderTest
//
//  Created by Nikita Rostovskii on 23.01.2021.
//

import UIKit

class MediaTimingFunctionEditControl: UIControl {
    
    public var isDragging = false
    
    private var yellow = UIColor.yellow
    private var blue = UIColor.blue
    private var gray = UIColor.gray
    private var white = UIColor.white
    private var shadow = UIColor.black
    private var font: UIFont = .systemFont(ofSize: 10)
    
    private let functionLineWidth: CGFloat = 4
    private let barsLineWidth: CGFloat = 4
    private let minimumDuration: CGFloat = 0.25
    let contentInsets = UIEdgeInsets(top: 34, left: 24, bottom: 34, right: 24)
    
    public var onUpdate: ((Float, Float, Float, Float, Float, Float) -> Void)?
    public var fps: CGFloat = 60 {
        didSet {
            updateTitles()
        }
    }
    
    private var timeStart: CGFloat = 0 { // 0 ... 1
        didSet {
            callHandler()
        }
    }
    private var timeEnd: CGFloat = 1 { // 0 ... 1
        didSet {
            callHandler()
        }
    }
    
    private var startValue: CGFloat = 0.2 { // 0 ... 1
        didSet {
            callHandler()
        }
    }
    private var endValue: CGFloat = 0.7 { // 0 ... 1
        didSet {
            callHandler()
        }
    }
    
    private func callHandler() {
        
        onUpdate?(Float(delay),
                  Float(duration),
                  Float((startValue - timeStart) / duration),
                  0,
                  Float((endValue - timeStart) / duration),
                  1)
    }
    
    private var delay: CGFloat { timeStart }
    private var duration: CGFloat { timeEnd - timeStart }
    
    private var previousLocation: CGPoint?
    
    lazy private var startKnob: DragKnob = {
        let knob = DragKnob()
        knob.desiredLabelLayout = .top
        return knob
    }()
    
    lazy private var endKnob: DragKnob = {
        let knob = DragKnob()
        knob.desiredLabelLayout = .bottom
        return knob
    }()
    
    lazy private var delayKnob: DragKnob = {
        let knob = DragKnob()
        knob.desiredLabelLayout = .right
        return knob
    }()
    
    lazy private var durationKnob: DragKnob = {
        let knob = DragKnob()
        knob.desiredLabelLayout = .right
        return knob
    }()
    
    lazy private var functionView: FunctionView = {
        let v = FunctionView(dataSource: self, lineWidth: functionLineWidth)
        return v
    }()
    
    lazy private var bottomBackgroundLineLayer: CAShapeLayer = {
        let l = CAShapeLayer()
        l.fillColor = UIColor.gray.cgColor
        return l
    }()
    
    lazy private var bottomLineLayer: CAShapeLayer = {
        let l = CAShapeLayer()
        l.fillColor = UIColor.blue.cgColor
        return l
    }()
    
    lazy private var topBackgroundLineLayer: CAShapeLayer = {
        let l = CAShapeLayer()
        l.fillColor = UIColor.gray.cgColor
        return l
    }()
    
    lazy private var topLineLayer: CAShapeLayer = {
        let l = CAShapeLayer()
        l.fillColor = UIColor.blue.cgColor
        return l
    }()
    
    lazy private var delayLineView: KnobVerticalLineView = {
        let v = KnobVerticalLineView()
        return v
    }()
    
    lazy private var durationLineView: KnobVerticalLineView = {
        let v = KnobVerticalLineView()
        return v
    }()
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateFrames()
        updateTitles()
    }
    
    public func setTimingValues(delay: Float, duration: Float, x1: Float, y1: Float, x2: Float, y2: Float) {
        self.timeStart = CGFloat(delay)
        self.timeEnd = CGFloat(duration + delay)
        
        let newStart = CGFloat(x1) * CGFloat(duration) + timeStart
        let newEnd = CGFloat(x2) * CGFloat(duration) + timeStart
        
        self.startValue = boundValue(newStart, toLowerValue: timeStart, upperValue: timeEnd)
        self.endValue = boundValue(newEnd, toLowerValue: timeStart, upperValue: timeEnd)
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        updateFrames()
        updateTitles()
        updateFunction()

        CATransaction.commit()
    }
    
    public func updateColors(yellow: UIColor, blue: UIColor, gray: UIColor, white: UIColor, shadow: UIColor, font: UIFont) {
        self.yellow = yellow
        self.blue = blue
        self.gray = gray
        self.white = white
        self.shadow = shadow
        self.font = font
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        backgroundColor = white
        topLineLayer.fillColor = blue.cgColor
        topBackgroundLineLayer.fillColor = gray.cgColor
        bottomLineLayer.fillColor = blue.cgColor
        bottomBackgroundLineLayer.fillColor = gray.cgColor
        functionView.lineColor = gray
        delayLineView.yellow = yellow
        delayLineView.white = white
        durationLineView.yellow = yellow
        durationLineView.white = white
        startKnob.white = white
        startKnob.textColor = blue
        startKnob.shadow = shadow
        endKnob.white = white
        endKnob.textColor = blue
        endKnob.shadow = shadow
        delayKnob.white = white
        delayKnob.textColor = yellow
        delayKnob.shadow = shadow
        durationKnob.white = white
        durationKnob.textColor = yellow
        durationKnob.shadow = shadow
        
        startKnob.font = font
        endKnob.font = font
        delayKnob.font = font
        durationKnob.font = font
        
        updateFrames()
        
        CATransaction.commit()
    }
    
    private func setupViews() {
        clipsToBounds = true
        
        delayKnob.functionView = functionView
        durationKnob.functionView = functionView
        endKnob.functionView = functionView
        startKnob.functionView = functionView
        
        addSubview(functionView)
        
        layer.addSublayer(bottomBackgroundLineLayer)
        layer.addSublayer(topBackgroundLineLayer)
        layer.addSublayer(bottomLineLayer)
        layer.addSublayer(topLineLayer)
        
        addSubview(delayLineView)
        addSubview(durationLineView)
        
        addSubview(delayKnob)
        addSubview(durationKnob)
        addSubview(endKnob)
        addSubview(startKnob)
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        
        let touchInset: CGFloat = -40
        if startKnob.frame.insetBy(dx: touchInset, dy: touchInset).contains(point) {
            return self
        } else if endKnob.frame.insetBy(dx: touchInset, dy: touchInset).contains(point) {
            return self
        } else if delayKnob.frame.insetBy(dx: touchInset, dy: touchInset).contains(point) {
            return self
        } else if durationKnob.frame.insetBy(dx: touchInset, dy: touchInset).contains(point) {
            return self
        }
        
        return nil
    }
    
    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        previousLocation = touch.location(in: self)
        
        let touchInset: CGFloat = -40
        
        if startKnob.frame.insetBy(dx: touchInset, dy: touchInset).contains(previousLocation!) {
            startKnob.isDragging = true
        } else if endKnob.frame.insetBy(dx: touchInset, dy: touchInset).contains(previousLocation!) {
            endKnob.isDragging = true
        } else if delayKnob.frame.insetBy(dx: touchInset, dy: touchInset).contains(previousLocation!) {
            delayKnob.isDragging = true
        } else if durationKnob.frame.insetBy(dx: touchInset, dy: touchInset).contains(previousLocation!) {
            durationKnob.isDragging = true
        }
        
        self.isDragging = startKnob.isDragging || endKnob.isDragging || delayKnob.isDragging || durationKnob.isDragging
        
        return isDragging
    }
    
    func boundValue(_ value: CGFloat, toLowerValue lowerValue: CGFloat, upperValue: CGFloat) -> CGFloat {
        return min(max(value, lowerValue), upperValue)
    }
    
    override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        guard previousLocation != nil else { return false }
        
        let location = touch.location(in: self)
        
        let deltaLocation = location.x - previousLocation!.x
        let deltaValue = deltaLocation / bounds.width
        
        self.previousLocation = location
        
        
        if startKnob.isDragging {
            var newStart = startValue + deltaValue
            newStart = boundValue(newStart, toLowerValue: timeStart, upperValue: timeEnd)
            startValue = newStart
        } else if endKnob.isDragging {
            var newEnd = endValue + deltaValue
            newEnd = boundValue(newEnd, toLowerValue: timeStart, upperValue: timeEnd)
            endValue = newEnd
        } else if delayKnob.isDragging {
            var newStart = timeStart + deltaValue
            newStart = boundValue(newStart, toLowerValue: 0, upperValue: timeEnd - minimumDuration)
            if newStart > startValue {
                startValue = newStart
            }
            if newStart > endValue {
                endValue = newStart
            }
            timeStart = newStart
        } else if durationKnob.isDragging {
            var newEnd = timeEnd + deltaValue
            newEnd = boundValue(newEnd, toLowerValue: timeStart + minimumDuration, upperValue: 1)
            if newEnd < startValue {
                startValue = newEnd
            }
            if newEnd < endValue {
                endValue = newEnd
            }
            timeEnd = newEnd
        }
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        updateFrames()
        updateTitles()
        updateFunction()

        CATransaction.commit()
        
        return true
    }
    
    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        isDragging = false
        startKnob.isDragging = false
        endKnob.isDragging = false
        delayKnob.isDragging = false
        durationKnob.isDragging = false
    }
    
    
    override func cancelTracking(with event: UIEvent?) {
        isDragging = false
        startKnob.isDragging = false
        endKnob.isDragging = false
        delayKnob.isDragging = false
        durationKnob.isDragging = false
    }
    
    private func updateFrames() {
        let contentFrame = bounds.inset(by: contentInsets)
        
        let valueKnobSize = CGSize(width: 18, height: 18)
        
        let startKnobOrigin = CGPoint(x: contentFrame.minX + contentFrame.width * startValue - valueKnobSize.width / 2,
                                      y: contentFrame.maxY - valueKnobSize.height / 2)
        
        let endKnobOrigin = CGPoint(x: contentFrame.minX + contentFrame.width * endValue - valueKnobSize.width / 2,
                                    y: contentFrame.minY - valueKnobSize.height / 2)
        
        
        
        let timeKnobSize = CGSize(width: 12, height: 24)
        
        let delayKnobOrigin = CGPoint(x: contentFrame.minX + contentFrame.width * timeStart - timeKnobSize.width / 2,
                                      y: contentFrame.midY - timeKnobSize.height / 2)
        
        let durationKnobOrigin = CGPoint(x: contentFrame.minX + contentFrame.width * timeEnd - timeKnobSize.width / 2,
                                         y: contentFrame.midY - timeKnobSize.height / 2)
        
        functionView.frame = contentFrame.insetBy(dx: -functionLineWidth / 2, dy: -functionLineWidth / 2)
        
        startKnob.frame = CGRect(origin: startKnobOrigin, size: valueKnobSize)
        endKnob.frame = CGRect(origin: endKnobOrigin, size: valueKnobSize)
        delayKnob.frame = CGRect(origin: delayKnobOrigin, size: timeKnobSize)
        durationKnob.frame = CGRect(origin: durationKnobOrigin, size: timeKnobSize)
        
        startKnob.setNeedsLayout()
        endKnob.setNeedsLayout()
        delayKnob.setNeedsLayout()
        durationKnob.setNeedsLayout()
        
        let bottomLineX = delayKnob.center.x
        let bottomLineWidth = startKnob.center.x - bottomLineX
        let bottomLineRect = CGRect(x: bottomLineX, y: contentFrame.maxY - barsLineWidth / 2, width: bottomLineWidth, height: barsLineWidth)
        
        bottomLineLayer.frame = layer.bounds
        if bottomLineRect.width < bottomLineRect.height {
            bottomLineLayer.path = nil
        } else {
            bottomLineLayer.path = CGPath(roundedRect: bottomLineRect, cornerWidth: bottomLineRect.height / 2, cornerHeight: bottomLineRect.height / 2, transform: nil)
        }
        
        
        let bottomBackgroundLineX = contentFrame.minX
        let bottomBackgroundLineWidth = contentFrame.maxX - bottomBackgroundLineX
        let bottomBackgroundLineRect = CGRect(x: bottomBackgroundLineX, y: contentFrame.maxY - barsLineWidth / 2, width: bottomBackgroundLineWidth, height: barsLineWidth)
        
        bottomBackgroundLineLayer.frame = layer.bounds
        bottomBackgroundLineLayer.path = CGPath(roundedRect: bottomBackgroundLineRect, cornerWidth: bottomBackgroundLineRect.height / 2, cornerHeight: bottomBackgroundLineRect.height / 2, transform: nil)
        
        
        let topLineX = endKnob.center.x
        let topLineWidth = durationKnob.center.x - topLineX
        let topLineRect = CGRect(x: topLineX, y: contentFrame.minY - barsLineWidth / 2, width: topLineWidth, height: barsLineWidth)
        
        topLineLayer.frame = layer.bounds
        if topLineRect.width < topLineRect.height {
            topLineLayer.path = nil
        } else {
            topLineLayer.path = CGPath(roundedRect: topLineRect, cornerWidth: topLineRect.height / 2, cornerHeight: topLineRect.height / 2, transform: nil)
        }
        
        
        let topBackgroundLineX = contentFrame.minX
        let topBackgroundLineWidth = contentFrame.maxX - topBackgroundLineX
        let topBackgroundLineRect = CGRect(x: topBackgroundLineX, y: contentFrame.minY - barsLineWidth / 2, width: topBackgroundLineWidth, height: barsLineWidth)
        
        topBackgroundLineLayer.frame = layer.bounds
        topBackgroundLineLayer.path = CGPath(roundedRect: topBackgroundLineRect, cornerWidth: topBackgroundLineRect.height / 2, cornerHeight: topBackgroundLineRect.height / 2, transform: nil)
        
        let verticalLineViewWidth = valueKnobSize.width
        delayLineView.frame = CGRect(x: delayKnob.center.x - verticalLineViewWidth / 2, y: 0, width: verticalLineViewWidth, height: bounds.height)
        delayLineView.topInset = contentInsets.top
        delayLineView.bottomInset = contentInsets.bottom
        delayLineView.centerKnobHeight = timeKnobSize.height
        
        durationLineView.frame = CGRect(x: durationKnob.center.x - verticalLineViewWidth / 2, y: 0, width: verticalLineViewWidth, height: bounds.height)
        durationLineView.topInset = contentInsets.top
        durationLineView.bottomInset = contentInsets.bottom
        durationLineView.centerKnobHeight = timeKnobSize.height
    }
    
    private func updateFunction() {
        functionView.setNeedsDisplay()
    }
    
    private func updateTitles() {
        startKnob.title = startValueTitle
        endKnob.title = endValueTitle
        
        delayKnob.title = "\(Int(timeStart * fps))f"
        durationKnob.title = "\(Int(timeEnd * fps))f"
    }
    
    private var startValueTitle: String { "\(Int((startValue - timeStart) / duration * 100))%" }
    private var endValueTitle: String { "\(100 - Int(((endValue - timeStart)) / duration * 100))%" }
    
}

extension MediaTimingFunctionEditControl: FunctionViewDataSource {
    
    var startPoint: CGPoint {
        CGPoint(x: timeStart, y: 0)
    }
    
    var endPoint: CGPoint {
        CGPoint(x: timeEnd, y: 1)
    }
    
    var startControlPoint: CGPoint {
        CGPoint(x: startValue, y: 0)
    }
    
    var endControlPoint: CGPoint {
        CGPoint(x: endValue, y: 1)
    }
}


class KnobVerticalLineView: UIView {
    
    private let edgeWhiteRadius: CGFloat = 5
    private let edgeYellowRadius: CGFloat = 3
    private let midYellowRadius: CGFloat = 1
    private let midPointCount = 7
    
    var centerKnobHeight: CGFloat = 0
    
    var topInset: CGFloat = 0 {
        didSet {
            setNeedsDisplay()
        }
    }
    var bottomInset: CGFloat = 0 {
        didSet {
            setNeedsDisplay()
        }
    }
    
    var white = UIColor.white {
        didSet {
            setNeedsDisplay()
        }
    }
    var yellow = UIColor.yellow {
        didSet {
            setNeedsDisplay()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = UIColor.clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        
        let top = CGPoint(x: bounds.midX, y: topInset)
        let bottom = CGPoint(x: bounds.midX, y: bounds.height - bottomInset)
        
        let bottomWhiteRect = CGRect(x: bottom.x - edgeWhiteRadius, y: bottom.y - edgeWhiteRadius, width: 2 * edgeWhiteRadius, height: 2 * edgeWhiteRadius)
        let bottomYellowRect = CGRect(x: bottom.x - edgeYellowRadius, y: bottom.y - edgeYellowRadius, width: 2 * edgeYellowRadius, height: 2 * edgeYellowRadius)
        
        let topWhiteRect = CGRect(x: top.x - edgeWhiteRadius, y: top.y - edgeWhiteRadius, width: 2 * edgeWhiteRadius, height: 2 * edgeWhiteRadius)
        let topYellowRect = CGRect(x: top.x - edgeYellowRadius, y: top.y - edgeYellowRadius, width: 2 * edgeYellowRadius, height: 2 * edgeYellowRadius)
        
        ctx.setFillColor(white.cgColor)
        ctx.addEllipse(in: topWhiteRect)
        ctx.drawPath(using: .fill)
        
        ctx.setFillColor(white.cgColor)
        ctx.addEllipse(in: bottomWhiteRect)
        ctx.drawPath(using: .fill)
        
        ctx.setFillColor(yellow.cgColor)
        ctx.addEllipse(in: topYellowRect)
        ctx.drawPath(using: .fill)
        
        ctx.setFillColor(yellow.cgColor)
        ctx.addEllipse(in: bottomYellowRect)
        ctx.drawPath(using: .fill)
        
        ctx.setFillColor(yellow.cgColor)
        
        
        let pointHeight = 2 * midYellowRadius
        
        var midTop = top.y + edgeWhiteRadius - pointHeight / 2
        var midBottom = bounds.midY - centerKnobHeight / 2 + pointHeight / 2
        let height = midBottom - midTop
        let step = height / CGFloat(midPointCount + 1)
        
        for i in 0 ..< midPointCount + 1 {
            if i == 0  {continue}
            let x = bounds.midX
            let y = midTop + step * CGFloat(i)
            let midRect = CGRect(x: x - midYellowRadius, y: y - midYellowRadius, width: 2 * midYellowRadius, height: 2 * midYellowRadius)
            
            ctx.addEllipse(in: midRect)
            ctx.drawPath(using: .fill)
        }
        
        midTop = bounds.midY + centerKnobHeight / 2 - pointHeight / 2
        midBottom = bottom.y - edgeWhiteRadius - pointHeight / 2
        
        for i in 0 ..< midPointCount + 1 {
            if i == 0  {continue}
            let x = bounds.midX
            let y = midTop + step * CGFloat(i)
            let midRect = CGRect(x: x - midYellowRadius, y: y - midYellowRadius, width: 2 * midYellowRadius, height: 2 * midYellowRadius)
            
            ctx.addEllipse(in: midRect)
            ctx.drawPath(using: .fill)
        }
    }
}



class DragKnob: UIView {
    
    enum LabelLayout {
        case left
        case top
        case bottom
        case right
    }
    
    private let textSpacing: CGFloat = 4
    
    weak var functionView: FunctionView?
    
    var font: UIFont = .systemFont(ofSize: 10) {
        didSet {
            titleLabel.font = font
            titleLabel.sizeToFit()
            setNeedsLayout()
        }
    }
    
    var textColor = UIColor.red {
        didSet {
            titleLabel.textColor = textColor
        }
    }
    var white = UIColor.white {
        didSet {
            knobView.backgroundColor = white
        }
    }
    var shadow = UIColor.black {
        didSet {
            knobView.layer.shadowColor = shadow.cgColor
        }
    }
    
    var desiredLabelLayout = LabelLayout.bottom {
        didSet {
            setNeedsDisplay()
        }
    }
    
    public var title: String {
        set {
            titleLabel.text = newValue
        }
        get {
            titleLabel.text ?? ""
        }
    }
    
    public var isDragging = false {
        didSet {
            self.alpha = isDragging ? 0.5 : 1
        }
    }
    
    lazy var knobView: UIView = {
        let v = UIView()
        v.backgroundColor = self.white
        v.isUserInteractionEnabled = false
        v.layer.masksToBounds = false
        v.layer.shadowColor = self.shadow.cgColor
        v.layer.shadowOpacity = 0.2
        v.layer.shadowRadius = 2
        v.layer.shadowOffset = .zero
        return v
    }()
    
    lazy var titleLabel: UILabel = {
        let l = UILabel()
        l.backgroundColor = .clear
        l.isUserInteractionEnabled = false
        l.font = font
        l.textColor = self.textColor
        l.textAlignment = .center
        return l
    }()
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    init() {
        super.init(frame: .zero)
        backgroundColor = .clear
        layer.masksToBounds = false
        isUserInteractionEnabled = false
        addSubview(titleLabel)
        addSubview(knobView)
        clipsToBounds = false
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        knobView.frame = bounds
        knobView.layer.cornerRadius = bounds.width / 2
        
        titleLabel.sizeToFit()
        let w = titleLabel.bounds.width
        let h = titleLabel.bounds.height
        let x: CGFloat
        let y: CGFloat
        
        let desiredRect: CGRect
        let oppositeRect: CGRect
        
        switch desiredLabelLayout {
        case .left:
            y = bounds.midY
            desiredRect = CGRect(x: -w - textSpacing, y: y - h / 2, width: w, height: h)
            oppositeRect = CGRect(x: bounds.width + textSpacing, y: y - h / 2, width: w, height: h)
        case .right:
            y = bounds.midY
            oppositeRect = CGRect(x: -w - textSpacing, y: y - h / 2, width: w, height: h)
            desiredRect = CGRect(x: bounds.width + textSpacing, y: y - h / 2, width: w, height: h)
        case .top:
            x = bounds.midX
            oppositeRect = CGRect(x: x - w / 2, y: bounds.height + textSpacing, width: w, height: h)
            desiredRect = CGRect(x: x - w / 2, y: -h - textSpacing, width: w, height: h)
        case .bottom:
            x = bounds.midX
            desiredRect = CGRect(x: x - w / 2, y: bounds.height + textSpacing, width: w, height: h)
            oppositeRect = CGRect(x: x - w / 2, y: -h - textSpacing, width: w, height: h)
        }
        
        let desiredRectConverted = convert(desiredRect, to: superview)
        let functionRectConverted = superview?.convert(functionView?.functionRect ?? .zero, from: functionView) ?? .zero
        let intersectBounds = !functionRectConverted.contains(desiredRectConverted) && desiredRectConverted.intersects(functionRectConverted)
        
        let superBounds = superview?.bounds.insetBy(dx: textSpacing, dy: textSpacing) ?? .zero
        let intersectSuperview = superBounds.contains(desiredRectConverted) != true
        if intersectSuperview {
            titleLabel.frame = oppositeRect
            return
        }
        
        if intersectBounds {
            titleLabel.frame = oppositeRect
            return
        }
        
        let intersectFuntion: Bool
        let xx = desiredRectConverted.midX - functionRectConverted.midX
        let yy = desiredRectConverted.midY - functionRectConverted.midY
        if xx < 0 || yy < 0 {
            intersectFuntion = functionView?.intersectsTop(with: desiredRectConverted) == true
        } else {
            intersectFuntion = functionView?.intersectsBottom(with: desiredRectConverted) == true
        }
        
        if intersectFuntion {
            titleLabel.frame = oppositeRect
            return
        }
        
        titleLabel.frame = desiredRect
    }
}

public protocol FunctionViewDataSource {
    
    var startPoint: CGPoint { get }
    var endPoint: CGPoint { get }
    var startControlPoint: CGPoint { get }
    var endControlPoint: CGPoint { get }
}

public class FunctionView: UIView  {
    
    public var lineColor: UIColor = .gray {
        didSet {
            setNeedsDisplay()
        }
    }
    public var dataSource: FunctionViewDataSource
    
    private var lineWidth: CGFloat
    
    private var startDrawPoint: CGPoint { convert(dataSource.startPoint) }
    private var endDrawPoint: CGPoint { convert(dataSource.endPoint) }
    
    private var startDrawControlPoint: CGPoint { convert(dataSource.startControlPoint) }
    private var endDrawControlPoint: CGPoint { convert(dataSource.endControlPoint) }
    
    private var startDrawPointOpposite: CGPoint { convert(.init(x: 0, y: 1)) }
    private var endDrawPointOpposite: CGPoint { convert(.init(x: 1, y: 0)) }
    
    public init(dataSource: FunctionViewDataSource, lineWidth: CGFloat) {
        self.lineWidth = lineWidth
        self.dataSource = dataSource
        super.init(frame: .zero)
        backgroundColor = .clear
        clipsToBounds = false
        layer.masksToBounds = false
        isUserInteractionEnabled = false
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public var functionRect: CGRect {
        self.bounds.inset(by: .init(top: lineWidth / 2,
                                    left: startDrawPoint.x,
                                    bottom: lineWidth / 2,
                                    right: self.bounds.width - endDrawPoint.x))
    }
    
    func intersectsTop(with rect: CGRect) -> Bool {
        let rect = convert(rect, from: superview)
        
        let path = UIBezierPath()
        path.move(to: startDrawPoint)
        path.addCurve(to: endDrawPoint,
                      controlPoint1: startDrawControlPoint,
                      controlPoint2: endDrawControlPoint)
        path.addLine(to: endDrawPointOpposite)
        path.close()
        
        if path.contains(CGPoint(x: rect.minX, y: rect.minY)) { return true }
        if path.contains(CGPoint(x: rect.minX, y: rect.maxY)) { return true }
        if path.contains(CGPoint(x: rect.maxX, y: rect.maxY)) { return true }
        if path.contains(CGPoint(x: rect.maxX, y: rect.minY)) { return true }
        
        return false
    }
    
    func intersectsBottom(with rect: CGRect) -> Bool {
        let rect = convert(rect, from: superview)
        
        let path = UIBezierPath()
        path.move(to: startDrawPoint)
        path.addCurve(to: endDrawPoint,
                      controlPoint1: startDrawControlPoint,
                      controlPoint2: endDrawControlPoint)
        path.addLine(to: startDrawPointOpposite)
        path.close()
        
        if path.contains(CGPoint(x: rect.minX, y: rect.minY)) { return true }
        if path.contains(CGPoint(x: rect.minX, y: rect.maxY)) { return true }
        if path.contains(CGPoint(x: rect.maxX, y: rect.maxY)) { return true }
        if path.contains(CGPoint(x: rect.maxX, y: rect.minY)) { return true }
        
        return false
    }
    
    private var path = UIBezierPath()
    
    override public func draw(_ rect: CGRect) {
        let path = UIBezierPath()
        
        lineColor.setStroke()
        path.lineWidth = lineWidth
        path.lineCapStyle = .round
        path.move(to: startDrawPoint)
        path.addCurve(to: endDrawPoint,
                      controlPoint1: startDrawControlPoint,
                      controlPoint2: endDrawControlPoint)
        path.stroke()
        self.path = path
        
        
//        let bounds = self.bounds.inset(by: .init(top: lineWidth / 2,
//                                                 left: startDrawPoint.x,
//                                                 bottom: lineWidth / 2,
//                                                 right: self.bounds.width - endDrawPoint.x))
//        let p = UIBezierPath(rect: bounds)
//        UIColor.green.setStroke()
//        p.stroke()
    }
    
    private func convert(_ pt: CGPoint) -> CGPoint {
        CGPoint(x: lineWidth / 2 + pt.x * (bounds.width - lineWidth),
                y: lineWidth / 2 + (1 - pt.y) * (bounds.height - lineWidth))
    }
}
