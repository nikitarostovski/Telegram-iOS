import UIKit

class ActionCell: BaseTableViewCell {
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .value1, reuseIdentifier: reuseIdentifier)
     }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateAppearance() {
        super.updateAppearance()
        self.updateState()
    }
    
    private func updateState() {
        guard let model = model as? ActionCellModel else { return }
        
        self.textLabel?.text = model.title
        self.detailTextLabel?.text = model.detailText
        
        switch model.color {
        case .normal:
            self.textLabel?.textColor = model.theme.textBlack
        case .action:
            self.textLabel?.textColor = model.theme.tintColor
        case .destructive:
            self.textLabel?.textColor = model.theme.destructiveColor
        }
        self.detailTextLabel?.textColor = model.theme.textGray
        
        if model.disclosureArrow {
            self.accessoryType = .disclosureIndicator
        } else {
            self.accessoryType = .none
        }
        
        if let indicatorButton = allSubviews.compactMap({ $0 as? UIButton }).last {
            let image = indicatorButton.backgroundImage(for: .normal)?.withRenderingMode(.alwaysTemplate)
            indicatorButton.setBackgroundImage(image, for: .normal)
            indicatorButton.tintColor = model.theme.textGray
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        guard let model = model as? ActionCellModel else { return }
        if let indicatorButton = allSubviews.compactMap({ $0 as? UIButton }).last {
            let image = indicatorButton.backgroundImage(for: .normal)?.withRenderingMode(.alwaysTemplate)
            indicatorButton.setBackgroundImage(image, for: .normal)
            indicatorButton.tintColor = model.theme.textGray
        }
    }
}

extension UIView {
   var allSubviews: [UIView] {
      return subviews.flatMap { [$0] + $0.allSubviews }
   }
}
