import UIKit

public struct TableViewSectionModel {
    
    public var title: String
    public var cellModels: [BaseTableViewCellModel]

    public init(title: String = "", cellModels: [BaseTableViewCellModel]) {
        self.title = title
        self.cellModels = cellModels
    }
}
