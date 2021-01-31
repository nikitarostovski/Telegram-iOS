import Foundation
import UIKit

public class ColorCellModel: BaseTableViewCellModel {
    
    public override var cellIdentifier: String {
        String(describing: ColorCell.self)
    }
    
    public override var height: CGFloat { 44 }
    
    public var title: String
    public var color: UIColor {
        didSet {
            onColorUpdate?()
        }
    }
    public var onColorUpdate: (() -> Void)?
    
    public init(theme: AnimationsTheme, title: String, color: UIColor, onColorUpdate: (() -> Void)? = nil) {
        self.title = title
        self.color = color
        self.onColorUpdate = onColorUpdate
        super.init(theme: theme)
    }
}
