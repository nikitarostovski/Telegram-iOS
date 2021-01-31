import Foundation
import UIKit

public class BackgroundCellModel: BaseTableViewCellModel {
    
    public var color1: UIColor
    public var color2: UIColor
    public var color3: UIColor
    public var color4: UIColor
    
    public var delay: Float
    public var duration: Float
    
    public var curve: (Float, Float, Float, Float)
    
    public override var cellIdentifier: String {
        String(describing: BackgroundCell.self)
    }
    
    public override var height: CGFloat { 180 }
    
    public init(theme: AnimationsTheme, color1: UIColor, color2: UIColor, color3: UIColor, color4: UIColor, delay: Float, duration: Float, curve: (Float, Float, Float, Float)) {
        
        self.color1 = color1
        self.color2 = color2
        self.color3 = color3
        self.color4 = color4
        
        self.delay = delay
        self.duration = duration
        self.curve = curve
        
        super.init(theme: theme)
    }
}
