import UIKit


class ColorCell: BaseTableViewCell, UITextFieldDelegate {
    
    private let defaultColor = UIColor.white
    
    private lazy var titleLabel: UILabel = {
        let l = UILabel()
        addSubview(l)
        return l
    }()
    
    private lazy var gr: UITapGestureRecognizer = {
        let gr = UITapGestureRecognizer(target: self, action: #selector(tap))
        gr.cancelsTouchesInView = false
        return gr
    }()
    
    private lazy var textField: UIValidatedTextField = {
        addGestureRecognizer(gr)
        let tf = UIValidatedTextField()
        tf.returnKeyType = .done
        tf.textAlignment = .center
        tf.layer.cornerRadius = 6
        tf.validator = isValidHex
        tf.delegate = self
        tf.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        addSubview(tf)
        return tf
    }()
    
    @objc func tap() {
        textField.becomeFirstResponder()
    }
    
    override func updateAppearance() {
        super.updateAppearance()
        guard let model = model as? ColorCellModel else { return }
    
        titleLabel.text = model.title
        textField.text = model.color.toHexString()
        
        updateTextField()
        
        textField.keyboardAppearance = model.theme.keyboard
        titleLabel.textColor = model.theme.textBlack
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let vSpacing: CGFloat = 8
        let hSpacing: CGFloat = 16
        let tfWidth: CGFloat = 96
        
        let bounds: CGRect
        if #available(iOS 11.0, *) {
            bounds = self.bounds.inset(by: safeAreaInsets)
        } else {
            bounds = self.bounds
        }
        
        textField.frame = CGRect(x: bounds.maxX - tfWidth - hSpacing, y: vSpacing, width: tfWidth, height: bounds.height - 2 * vSpacing)
        titleLabel.frame = CGRect(x: bounds.minX + hSpacing, y: vSpacing, width: bounds.width - 3 * hSpacing - tfWidth, height: bounds.height - 2 * vSpacing)
    }
    
    private func updateTextField() {
        guard let model = model as? ColorCellModel else { return }
        textField.backgroundColor = model.color
        textField.textColor = model.color.oppositeColor()
    }
    
    @objc func textFieldDidChange() {
        guard let model = model as? ColorCellModel else { return }
        let text = textField.text ?? ""
        let color = makeColor(from: text)
        model.color = color
        textField.text = textField.text?.uppercased()
        updateTextField()
    }
    
    private func makeColor(from string: String) -> UIColor {
        return UIColor(hex: string) ?? defaultColor
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.endEditing(true)
        return true
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let text = textField.text else { return true }
        var result = true
        
        if text.count == 1, string.isEmpty { return false }
        if text.count + string.count > 7 { return false }
        
        if let extTextField = textField as? UIValidatedTextField {
            result = extTextField.validate(input: string)
        }
        
        return result
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        gr.isEnabled = false
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        gr.isEnabled = true
        guard let model = model as? ColorCellModel else { return }
        textField.text = model.color.toHexString()
    }
    
    func isValidHex(text: String) -> Bool {
        let regexp = "[0-9a-fA-F]*"
        return text.matches(regexp)
    }
}


extension UIColor {
    
    convenience init?(hex: String, alpha: CGFloat = 1.0) {
        var hexFormatted: String = hex.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).uppercased()
        
        if hexFormatted.hasPrefix("#") {
            hexFormatted = String(hexFormatted.dropFirst())
        }
        
        guard hexFormatted.count == 6 else { return nil }
        
        var rgbValue: UInt64 = 0
        Scanner(string: hexFormatted).scanHexInt64(&rgbValue)
        
        self.init(red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
                  green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
                  blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
                  alpha: alpha)
    }
    
    func oppositeColor(threshold: Float = 0.5) -> UIColor {
        let originalCGColor = self.cgColor
        
        let RGBCGColor = originalCGColor.converted(to: CGColorSpaceCreateDeviceRGB(), intent: .defaultIntent, options: nil)
        guard let components = RGBCGColor?.components else {
            return .black
        }
        guard components.count >= 3 else {
            return .black
        }
        
        let brightness = Float(((components[0] * 299) + (components[1] * 587) + (components[2] * 114)) / 1000)
        return (brightness > threshold) ? UIColor.black : UIColor.white
    }
    
    func toHexString() -> String {
        var r:CGFloat = 0
        var g:CGFloat = 0
        var b:CGFloat = 0
        var a:CGFloat = 0
        
        getRed(&r, green: &g, blue: &b, alpha: &a)
        
        let rgb:Int = (Int)(r*255)<<16 | (Int)(g*255)<<8 | (Int)(b*255)<<0
        
        return String(format:"#%06x", rgb).uppercased()
    }
}

extension String {
    func matches(_ expression: String) -> Bool {
        if let range = range(of: expression, options: .regularExpression, range: nil, locale: nil) {
            return range.lowerBound == startIndex && range.upperBound == endIndex
        } else {
            return false
        }
    }
}

class UIValidatedTextField: UITextField {
    
    let padding = UIEdgeInsets(top: 1, left: 4, bottom: 0, right: 4)
    
    override open func textRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.inset(by: padding)
    }
    
    override open func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.inset(by: padding)
    }
    
    override open func editingRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.inset(by: padding)
    }
    
    
    public var validator: (String) -> Bool = { _ in return true }
    
    func validate(input string: String) -> Bool {
        return validator(string)
    }
    
    func validate() -> Bool {
        if let contents = text {
            return validator(contents)
        } else {
            return true
        }
    }
}
