import UIKit

open class BaseTableViewCellModel {
    
    open var height: CGFloat {
        return 0
    }
    
    open var cellIdentifier: String {
        return ""
    }
    
    
    var theme: AnimationsTheme
    
    open var tapAction: (() -> Void)?
    open var reloadView: (() -> Void)?
    open var userInteractionEnabled = true
    
    init(theme: AnimationsTheme, tapAction: (() -> Void)? = nil, reloadView: (() -> Void)? = nil) {
        self.theme = theme
        self.tapAction = tapAction
        self.reloadView = reloadView
    }
}
