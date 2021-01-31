import UIKit

public class ActionCellModel: BaseTableViewCellModel {
    
    enum Color {
        case normal
        case action
        case destructive
    }
    
    var color: Color
    
    public let title: String
    public var detailText: String?
    
    public var disclosureArrow: Bool
    
    public override var cellIdentifier: String {
        String(describing: ActionCell.self)
    }
    
    public override var height: CGFloat { 44 }
    
    init(theme: AnimationsTheme, title: String, detail: String? = nil, disclosureEnabled: Bool = false, color: Color = .normal) {
        self.color = color
        self.title = title
        self.detailText = detail
        self.disclosureArrow = disclosureEnabled
        
        super.init(theme: theme)
    }
}
