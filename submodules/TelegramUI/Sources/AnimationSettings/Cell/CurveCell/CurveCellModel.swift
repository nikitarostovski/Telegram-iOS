import UIKit

public class CurveCellModel: BaseTableViewCellModel {
    
    public var fps: Float?
    public var duration: Float
    public var delay: Float
    public var timings: (Float, Float, Float, Float)
    
    public var onUpdate: (() -> Void)?
    
    public override var height: CGFloat { 210 }
    
    public override var cellIdentifier: String {
        String(describing: CurveCell.self)
    }
    
    public init(theme: AnimationsTheme, duration: Float, delay: Float, timings: (Float, Float, Float, Float), fps: Float?) {
        self.fps = fps
        self.timings = timings
        self.duration = duration
        self.delay = delay
        
        super.init(theme: theme)
    }
}
