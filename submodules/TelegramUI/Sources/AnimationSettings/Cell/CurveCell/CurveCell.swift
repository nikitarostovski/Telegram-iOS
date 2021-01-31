import UIKit

class CurveCell: BaseTableViewCell {
    
    private lazy var control: MediaTimingFunctionEditControl = {
        let c = MediaTimingFunctionEditControl()
        addSubview(c)
        return c
    }()
    
    
    override func updateAppearance() {
        super.updateAppearance()
        self.selectionStyle = .none
        
        updateState()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let bounds: CGRect
        if #available(iOS 11.0, *) {
            bounds = self.bounds.inset(by: safeAreaInsets)
        } else {
            bounds = self.bounds
        }
        control.frame = bounds
    }
    
    override func prepareForReuse() {
        if let model = self.model as? CurveCellModel {
            model.onUpdate = nil
        }
        control.onUpdate = nil
        super.prepareForReuse()
    }
    
    private func updateState() {
        guard let model = model as? CurveCellModel else { return }
        
        control.updateColors(yellow: model.theme.curveYellow,
                             blue: model.theme.tintColor,
                             gray: model.theme.curveLightGray,
                             white: model.theme.cellBackground,
                             shadow: model.theme.shadow,
                             font: .systemFont(ofSize: 10))
        
        control.setTimingValues(delay: model.delay,
                                duration: model.duration,
                                x1: model.timings.0,
                                y1: model.timings.1,
                                x2: model.timings.2,
                                y2: model.timings.3)
        
        control.onUpdate = { [weak self] delay, duration, x1, y1, x2, y2 in
            guard let model = self?.model as? CurveCellModel else { return }
            model.delay = delay
            model.duration = duration
            model.timings = (x1, y1, x2, y2)
            model.onUpdate?()
        }
        
        if let fps = model.fps {
            control.fps = CGFloat(fps * 60)
        }
        
        model.reloadView = { [weak self] in
            self?.updateState()
        }
    }
}
