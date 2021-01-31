//
//  SettingsBackgroundController.swift
//  settingsui
//
//  Created by Nikita Rostovskii on 25.01.2021.
//

import UIKit

#if canImport(Display)
import Display
#endif

extension UIAlertController {
    
    func setBackgroudColor(color: UIColor) {
        if let bgView = self.view.subviews.first,
           let groupView = bgView.subviews.first,
           let contentView = groupView.subviews.first {
            contentView.backgroundColor = color
        }
    }
    
    func setTitle(font: UIFont?, color: UIColor?) {
        guard let title = self.title else { return }
        let attributeString = NSMutableAttributedString(string: title)
        if let titleFont = font {
            attributeString.addAttributes([NSAttributedString.Key.font : titleFont],
                                          range: NSMakeRange(0, title.utf8.count))
        }
        if let titleColor = color {
            attributeString.addAttributes([NSAttributedString.Key.foregroundColor : titleColor],
                                          range: NSMakeRange(0, title.utf8.count))
        }
        self.setValue(attributeString, forKey: "attributedTitle")
    }
    
    func setMessage(font: UIFont?, color: UIColor?) {
        guard let title = self.message else {
            return
        }
        let attributedString = NSMutableAttributedString(string: title)
        if let titleFont = font {
            attributedString.addAttributes([NSAttributedString.Key.font : titleFont], range: NSMakeRange(0, title.utf8.count))
        }
        if let titleColor = color {
            attributedString.addAttributes([NSAttributedString.Key.foregroundColor : titleColor], range: NSMakeRange(0, title.utf8.count))
        }
        self.setValue(attributedString, forKey: "attributedMessage")
    }
    
    func setTint(color: UIColor) {
        self.view.tintColor = color
    }
}

final class SettingsBackgroundController: UIViewController {
    
    private let bottomViewHeight: CGFloat = 50
    
    private var background: BackgroundView?
    private var bottomView: UIView?
    private var button: UIButton?
    
    var theme: AnimationsTheme?
    
    var settings: AnimSettingsHandler? {
        didSet {
            updateSettings()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Background"
    
        let b = BackgroundView()
        self.background = b
        view.addSubview(b)
        
        let v = UIView()
        v.backgroundColor = UIColor.white   
        self.bottomView = v
        view.addSubview(v)
        
        let a = UIButton(type: .system)
        a.backgroundColor = .clear
        a.setTitle("Animate", for: .normal)
        a.addTarget(self, action: #selector(animateTap), for: .touchUpInside)
        self.button = a
        bottomView?.addSubview(a)
        
        updateSettings()
        
        view.tintColor = theme?.tintColor
        bottomView?.backgroundColor = theme?.cellBackground
    }
    
    @objc func animateTap() {
        background?.animate()
    }
    
    private func updateSettings() {
        guard let background = background, let settings = settings?.data[.background] as? BackgroundSettings else { return }
        background.color1 = settings.col1
        background.color2 = settings.col2
        background.color3 = settings.col3
        background.color4 = settings.col4
        background.animationCurve = settings.curve.tuple
        let scale = CGFloat(settings.durationType.rawValue) / CGFloat(60)
        background.animationDelay = TimeInterval(settings.curve.delay) * TimeInterval(scale)
        background.animationDuration = TimeInterval(settings.curve.duration) * TimeInterval(scale)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        background?.frame = view.bounds
        
        var viewHeight = bottomViewHeight
        if #available(iOS 11.0, *) {
            viewHeight += view.safeAreaInsets.bottom
        }
        
        bottomView?.frame = CGRect(x: 0, y: view.bounds.height - viewHeight, width: view.bounds.width, height: viewHeight)
        
        button?.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: bottomViewHeight)
    }
}
