import UIKit

open class BaseTableViewCell: UITableViewCell {
    
    open weak var model: BaseTableViewCellModel?
    
    private lazy var backView: UIView = {
        let v = UIView()
        addSubview(v)
        self.selectedBackgroundView = v
        return v
    }()
    
    open var cellIdentifier: String {
        return String(describing: self)
    }
    
    override open func prepareForReuse() {
        self.model?.reloadView = nil
        self.model = nil
    }
    
    open func setup(with model: BaseTableViewCellModel) {
        self.model = model
        updateAppearance()
    }
    
    open func updateAppearance() {
        if let theme = model?.theme {
            backgroundColor = theme.cellBackground
            backView.backgroundColor = theme.background
        }
        self.contentView.isUserInteractionEnabled = false
//        isUserInteractionEnabled = true
//        selectionStyle = .none
    }
}
