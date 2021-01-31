import UIKit

#if canImport(Display)
import Display
#endif

class BackgroundCell: BaseTableViewCell {
    
    private lazy var view: BackgroundView = {
        let c = BackgroundView()
//        c.isUserInteractionEnabled = false
        addSubview(c)
        return c
    }()
    
    override func updateAppearance() {
        super.updateAppearance()
        guard let model = model as? BackgroundCellModel else { return }
        selectionStyle = .none
        self.separatorInset = .zero
        
        let gr = UITapGestureRecognizer(target: self, action: #selector(tap))
        gr.cancelsTouchesInView = false
        view.addGestureRecognizer(gr)
        
        model.tapAction = { [weak self] in
            self?.view.animate()
            
        }
        
        model.reloadView = { [weak self] in
            self?.updateState()
        }
        
        updateState()
    }
    
    @objc func tap() {
        guard let model = model as? BackgroundCellModel else { return }
        view.animationCurve = model.curve
        view.animationDuration = Double(model.duration)
        view.animationDelay = Double(model.delay)
        
        view.animate()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        view.frame = bounds
    }
    
    private func updateState() {
        guard let model = model as? BackgroundCellModel else { return }
        
        view.color1 = model.color1
        view.color2 = model.color2
        view.color3 = model.color3
        view.color4 = model.color4
        
        view.animationCurve = model.curve
        view.animationDuration = Double(model.duration)
        view.animationDelay = Double(model.delay)
    }
}
