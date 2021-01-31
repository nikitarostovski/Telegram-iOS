import UIKit

public extension UITableView {
    
    func numberOfSections(in structure: TableViewStructure) -> NSInteger {
        return structure.sections.count
    }
    
    func numberOfRows(in structure: TableViewStructure, section: NSInteger) -> NSInteger {
        guard section >= 0 && section < structure.sections.count else {
            return 0
        }
        return structure.sections[section].cellModels.count
    }
    
    func dequeueReusableCell(with structure: TableViewStructure, indexPath: IndexPath) -> BaseTableViewCell {
        let model = structure.cellModel(for: indexPath)
        var baseTableViewCell: BaseTableViewCell
        if let cell = dequeueReusableCell(withIdentifier: model.cellIdentifier) as? BaseTableViewCell {
            baseTableViewCell = cell
        } else {
            return BaseTableViewCell()
        }
        baseTableViewCell.setup(with: model)
        return baseTableViewCell
    }
}
