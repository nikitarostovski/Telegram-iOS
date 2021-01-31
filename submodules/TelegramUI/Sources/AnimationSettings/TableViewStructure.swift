import UIKit

public class TableViewStructure {
    
    public var sections = [TableViewSectionModel]()
    
    public init() { }
    
    public func clear() {
        sections = [TableViewSectionModel]()
    }
    
    public func addSection(section: TableViewSectionModel) {
        sections.append(section)
    }
    
    public func cellModel(for indexPath: IndexPath) -> BaseTableViewCellModel {
        let sectionIndex = indexPath.section
        let rowIndex = indexPath.row
        let section = sections[sectionIndex]
        return section.cellModels[rowIndex]
    }
    
    public func indexPath(for model: BaseTableViewCellModel) -> IndexPath? {
        for sectionIndex in sections.indices {
            let section = sections[sectionIndex]
            for modelIndex in section.cellModels.indices {
                if section.cellModels[modelIndex] === model {
                    return IndexPath(row: modelIndex, section: sectionIndex)
                }
            }
        }
        return nil
    }
    
    public func addModel(_ model: BaseTableViewCellModel, inSection index: Int) {
        var newSections = [TableViewSectionModel]()
        sections.indices.forEach { [weak self] oldSectionIndex in
            guard let self = self else { return }
            var oldSection = self.sections[oldSectionIndex]
            if oldSectionIndex == index {
                oldSection.cellModels.append(model)
            }
            newSections.append(oldSection)
        }
        sections = newSections
    }
}
