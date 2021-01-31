//
//  ViewController.swift
//  settingsui
//
//  Created by Nikita Rostovskii on 25.01.2021.
//

import UIKit

public struct AnimationsTheme {
    
    var background: UIColor = .black
    var cellBackground: UIColor = .darkGray
    
    var textBlack: UIColor = .white
    var textGray: UIColor = .lightGray
    var separator: UIColor = .lightGray
    var navigationBar: UIColor = .darkGray
    
    var sectionTitleColor: UIColor = .gray
    
    var tintColor: UIColor = .red
    var destructiveColor: UIColor = .purple
    
    var curveYellow: UIColor = .yellow
    var curveLightGray: UIColor = .lightGray
    
    var shadow: UIColor = .white
    
    var keyboard: UIKeyboardAppearance = .dark
}

class ASViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UIGestureRecognizerDelegate {

    private var structure = TableViewStructure()
    private var tableView: UITableView!
    
    
    var theme = AnimationsTheme()
    
    private var curSettings: AnimSettingsHandler = AnimSettingsHandler.load()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.tableView = UITableView(frame: view.bounds, style: .grouped)
        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.tableView.showsVerticalScrollIndicator = false
//        self.tableView.isExclusiveTouch = false
        self.tableView.canCancelContentTouches = false
        
        if #available(iOS 13, *) {
            self.isModalInPresentation = true
        }
        
        tableView.register(ActionCell.self, forCellReuseIdentifier: String(describing: ActionCell.self))
        tableView.register(CurveCell.self, forCellReuseIdentifier: String(describing: CurveCell.self))
        tableView.register(BackgroundCell.self, forCellReuseIdentifier: String(describing: BackgroundCell.self))
        tableView.register(ColorCell.self, forCellReuseIdentifier: String(describing: ColorCell.self))
        self.view.addSubview(self.tableView)
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTap))
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(saveTap))
        
        let gr = UITapGestureRecognizer(target: self, action: #selector(backTap))
        gr.cancelsTouchesInView = false
        self.view.addGestureRecognizer(gr)
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        updateStructure()
        updateTheme()
    }
    
    func updateTheme() {
        view.backgroundColor = theme.background
        tableView.backgroundColor = theme.background
        tableView.separatorColor = theme.separator
        
        navigationController?.navigationBar.barTintColor = theme.navigationBar
        navigationController?.navigationBar.tintColor = theme.tintColor
        
        let titleDict: NSDictionary = [NSAttributedString.Key.foregroundColor: theme.textBlack]
        navigationController?.navigationBar.titleTextAttributes = titleDict as? [NSAttributedString.Key : Any]
        
        tableView.sectionIndexColor = theme.sectionTitleColor
        reload()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
//        navigationController?.presentationController?.presentedView?.gestureRecognizers?.forEach {
//           $0.delegate = self
//        }
    }
    
//    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
//        return true
////        if gestureRecognizer === UIPanGestureRecognizer.self && otherGestureRecognizer === UISwipeGestureRecognizer.self {
////            return true
////        }
////        return false
//    }
//
//    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
//        return false
//    }
    
    
    
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        view.endEditing(true)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        tableView.frame = view.bounds
    }
    
    @objc func cancelTap() {
        navigationController?.dismiss(animated: true, completion: nil)
    }
    
    @objc func saveTap() {
        curSettings.save()
        navigationController?.dismiss(animated: true, completion: nil)
    }
    
    @objc func backTap() {
        view.endEditing(true)
    }
    
    @objc func keyboardWillShow(notification: Notification) {
        guard let keyboardHeight = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.height else { return }
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval ?? 0
        let curve = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? 0

        let c = UIView.AnimationOptions(rawValue: curve)
        
        UIView.animate(withDuration: duration, delay: 0, options: [c]) {
            self.tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: keyboardHeight, right: 0)
        } completion: { (_) in
            
        }
    }

    @objc func keyboardWillHide(notification: Notification) {
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval ?? 0
        let curve = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? 0

        let c = UIView.AnimationOptions(rawValue: curve)
        
        UIView.animate(withDuration: duration, delay: 0, options: [c]) {
            self.tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        } completion: { (_) in
            
        }
    }
    
    private func updateStructure() {
        structure.clear()
        
        let typeCell = ActionCellModel(theme: theme, title: "Animation Type", detail: curSettings.activeType.rawValue, disclosureEnabled: true)
        typeCell.tapAction = { [weak self] in
            guard let self = self else { return }
            let vc = SettingsTypeController()
            vc.theme = self.theme
            vc.onSelect = { index in
                switch index {
                case 0: self.curSettings.activeType = .smallMessage
                case 1: self.curSettings.activeType = .linkPreview
                case 2: self.curSettings.activeType = .singleEmoji
                case 3: self.curSettings.activeType = .sticker
                case 4: self.curSettings.activeType = .voice
                case 5: self.curSettings.activeType = .video
                case 6: self.curSettings.activeType = .background
                default: break
                }
                self.updateStructure()
            }
            self.navigationController?.pushViewController(vc, animated: true)
        }
        
        let durationCell = ActionCellModel(theme: theme, title: "Duration", detail: "\(curSettings.activeSettings.durationType.rawValue)f", disclosureEnabled: true)
        durationCell.tapAction = { [weak self] in
            guard let self = self else { return }
            let theme = self.theme
            let durationSelection = UIAlertController(title: nil, message: "Duration", preferredStyle: .actionSheet)
            durationSelection.setBackgroudColor(color: theme.navigationBar)
            durationSelection.setTint(color: theme.tintColor)
            durationSelection.setTitle(font: nil, color: theme.textBlack)
            
            durationSelection.addAction(UIAlertAction(title: "30f", style: .default, handler: { (a) in
                self.curSettings.activeSettings.durationType = .frames30
//                durationCell.detailText = a.title
                self.updateStructure()
            }))
            durationSelection.addAction(UIAlertAction(title: "45f", style: .default, handler: { (a) in
                self.curSettings.activeSettings.durationType = .frames45
//                durationCell.detailText = a.title
                self.updateStructure()
            }))
            durationSelection.addAction(UIAlertAction(title: "60f (1 sec)", style: .default, handler: { (a) in
                self.curSettings.activeSettings.durationType = .frames60
//                durationCell.detailText = a.title
                self.updateStructure()
            }))
            durationSelection.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            self.present(durationSelection, animated: true, completion: nil)
            
            if let cancelBackgroundViewType = NSClassFromString("_UIAlertControlleriOSActionSheetCancelBackgroundView") as? UIView.Type {
                cancelBackgroundViewType.appearance().subviewsBackgroundColor = theme.navigationBar
            }
        }
        
        let shareCell = ActionCellModel(theme: theme, title: "Share Parameters", color: .action)
        shareCell.tapAction = { [weak self] in
            guard let self = self else { return }
            
            guard let text = self.curSettings.exportSettings() else {
                return
            }
            
            let textView = UITextView()
            textView.backgroundColor = self.theme.background
            textView.textColor = self.theme.textBlack
            textView.text = text
            textView.isEditable = false
            textView.linkTextAttributes = nil
            textView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            
            UIPasteboard.general.string = text
            
            let vc = UIAlertController(title: "Share", message: "Following string contains settings data you can modify elsewhere. It has been copied to clipboard as well", preferredStyle: .alert)
            vc.addAction(UIAlertAction(title: "Done", style: .default, handler: nil))
            
            let controller = UIViewController()
            textView.frame = controller.view.frame
            controller.view.addSubview(textView)
            vc.setValue(controller, forKey: "contentViewController")
            
            vc.setBackgroudColor(color: .red)//self.theme.navigationBar)
            vc.setTint(color: self.theme.tintColor)
            vc.setTitle(font: nil, color: self.theme.textBlack)
            vc.setMessage(font: nil, color: self.theme.textGray)
            
            self.present(vc, animated: true, completion: nil)
        }
        
        let importCell = ActionCellModel(theme: theme, title: "Import Parameters", color: .action)
        importCell.tapAction = { [weak self] in
            guard let self = self else { return }
            
            guard let text = self.curSettings.exportSettings() else {
                return
            }
            
            let textView = UITextView()
            textView.backgroundColor = self.theme.background
            textView.textColor = self.theme.textBlack
            textView.isEditable = true
            textView.keyboardAppearance = self.theme.keyboard
            textView.linkTextAttributes = nil
            textView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            
            UIPasteboard.general.string = text
            
            let vc = UIAlertController(title: "Import", message: "Paste your settings string below. Settings screen will be updated right after you press 'Import' button", preferredStyle: .alert)
            vc.addAction(UIAlertAction(title: "Import", style: .default, handler: { _ in
                let newString = textView.text ?? ""
                if let newSettings = AnimSettingsHandler.importSettings(string: newString) {
                    let curType = self.curSettings.activeType
                    self.curSettings = newSettings
                    self.curSettings.activeType = curType
                    self.updateStructure()
                } else {
                    // Error
                    let vc = UIAlertController(title: "Import failed", message: "Failed to create valid settings from string provided", preferredStyle: .alert)
                    vc.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    
                    vc.setBackgroudColor(color: self.theme.navigationBar)
                    vc.setTint(color: self.theme.tintColor)
                    vc.setTitle(font: nil, color: self.theme.textBlack)
                    vc.setMessage(font: nil, color: self.theme.textGray)
                    
                    self.present(vc, animated: true, completion: nil)
                }
            }))
            
            vc.addAction(UIAlertAction(title: "Cancel", style: .default, handler: nil))
            
            let controller = UIViewController()
            textView.frame = controller.view.frame
            controller.view.addSubview(textView)
            vc.setValue(controller, forKey: "contentViewController")
            
            vc.setBackgroudColor(color: self.theme.navigationBar)
            vc.setTint(color: self.theme.tintColor)
            vc.setTitle(font: nil, color: self.theme.textBlack)
            vc.setMessage(font: nil, color: self.theme.textGray)
            
            self.present(vc, animated: true, completion: nil)
            textView.becomeFirstResponder()
        }
        
        let restoreCell = ActionCellModel(theme: theme, title: "Restore to Default", color: .destructive)
        restoreCell.tapAction = { [weak self] in
            guard let self = self else { return }
            let vc = UIAlertController(title: "Restore to Default", message: "This will reset all configurations", preferredStyle: .alert)
            vc.addAction(UIAlertAction(title: "Reset", style: .destructive, handler: { a in
                let active = self.curSettings.activeType
                self.curSettings = AnimSettingsHandler.loadDefaults()
                self.curSettings.activeType = active
                self.updateStructure()
            }))
            vc.addAction(UIAlertAction(title: "Cancel", style: .default, handler: nil))
            
            vc.setBackgroudColor(color: self.theme.navigationBar)
            vc.setTint(color: self.theme.tintColor)
            vc.setTitle(font: nil, color: self.theme.textBlack)
            vc.setMessage(font: nil, color: self.theme.textGray)
            
            self.present(vc, animated: true, completion: nil)
        }
        
        structure.addSection(section: TableViewSectionModel(cellModels: [typeCell, durationCell, shareCell, importCell, restoreCell]))
        
        makeSettingsSections().forEach {
            structure.addSection(section: $0)
        }
        reload()
    }
    
    private func reload() {
        cells.removeAll()
        tableView.reloadData()
    }
    
    var cells = [IndexPath: BaseTableViewCell]()
    
    public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return structure.sections[section].title
    }

    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return structure.cellModel(for: indexPath).height
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableView.numberOfRows(in: structure, section: section)
    }
    
    public func numberOfSections(in tableView: UITableView) -> Int {
        return tableView.numberOfSections(in: structure)
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = cells[indexPath] {
            return cell
        }
        let model = structure.cellModel(for: indexPath)
        let newCell: BaseTableViewCell
        switch model {
        case is ActionCellModel:
            newCell = ActionCell(style: .default, reuseIdentifier: model.cellIdentifier)
        case is CurveCellModel:
            newCell = CurveCell(style: .default, reuseIdentifier: model.cellIdentifier)
        case is BackgroundCellModel:
            newCell = BackgroundCell(style: .default, reuseIdentifier: model.cellIdentifier)
        case is ColorCellModel:
            newCell = ColorCell(style: .default, reuseIdentifier: model.cellIdentifier)
        default:
            return UITableViewCell()
        }
        newCell.setup(with: model)
        cells[indexPath] = newCell
        return newCell
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        structure.cellModel(for: indexPath).tapAction?()
    }
    
    public func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let header = view as! UITableViewHeaderFooterView
        header.textLabel?.textColor = theme.sectionTitleColor
    }
}

extension ASViewController {
    
    func makeSettingsSections() -> [TableViewSectionModel] {
        switch curSettings.activeType {
        case .background:
            return makeBackgroundSettingsSections()
        case .smallMessage:
            return makeSmallMessageSettingsSections()
//        case .bigMessage:
//            return makeBigMessageSettingsSections()
        case .linkPreview:
            return makeLinkSettingsSections()
        case .singleEmoji:
            return makeEmojiSettingsSections()
        case .sticker:
            return makeStickerSettingsSections()
        case .voice:
            return makeVoiceSettingsSections()
        case .video:
            return makeVideoSettingsSections()
        }
    }
    
    func makeBackgroundSettingsSections() -> [TableViewSectionModel] {
        guard let curSettings = curSettings.activeSettings as? BackgroundSettings else { return [] }
        let c1 = curSettings.col1
        let c2 = curSettings.col2
        let c3 = curSettings.col3
        let c4 = curSettings.col4
        
        let scale = CGFloat(curSettings.durationType.rawValue) / CGFloat(60)
        
        let backgroundModel = BackgroundCellModel(theme: theme, color1: c1, color2: c2, color3: c3, color4: c4, delay: curSettings.curve.delay * Float(scale), duration: curSettings.curve.duration * Float(scale), curve: curSettings.curve.tuple)
        
        
        let gradientPosModel = CurveCellModel(theme: theme, duration: curSettings.curve.duration,
                                              delay: curSettings.curve.delay,
                                              timings: curSettings.curve.tuple,
                                              fps: curSettings.durationType.seconds)
        gradientPosModel.onUpdate = { [weak self] in
            guard let curSettings = self?.curSettings.activeSettings as? BackgroundSettings else { return }
            curSettings.curve = AnimationCurve(tuple: gradientPosModel.timings, delay: gradientPosModel.delay, duration: gradientPosModel.duration)
            
            let scale = CGFloat(curSettings.durationType.rawValue) / CGFloat(60)
            
            backgroundModel.delay = gradientPosModel.delay * Float(scale)
            backgroundModel.duration = gradientPosModel.duration * Float(scale)
            backgroundModel.curve = gradientPosModel.timings
            
        }
        let gradSec = TableViewSectionModel(title: "Gradient position", cellModels: [gradientPosModel])

        
        
        let fullscreenModel = ActionCellModel(theme: theme, title: "Open Full Screen", color: .action)
        fullscreenModel.tapAction = { [weak self] in
            guard let self = self else { return }
            let vc = SettingsBackgroundController()
            vc.theme = self.theme
            vc.settings = self.curSettings
            self.navigationController?.pushViewController(vc, animated: true)
        }
        let backSec = TableViewSectionModel(title: "Background preview", cellModels: [backgroundModel, fullscreenModel])
        
        let c1Model = ColorCellModel(theme: theme, title: "Color 1", color: c1)
        let c2Model = ColorCellModel(theme: theme, title: "Color 2", color: c2)
        let c3Model = ColorCellModel(theme: theme, title: "Color 3", color: c3)
        let c4Model = ColorCellModel(theme: theme, title: "Color 4", color: c4)
        
        c1Model.onColorUpdate = { [weak self] in
            guard let self = self else { return }
            let s = c1Model.color.toHexString().suffix(6)
            curSettings.color1 = String(s)
            backgroundModel.color1 = c1Model.color
            backgroundModel.reloadView?()
        }
        
        c2Model.onColorUpdate = { [weak self] in
            guard let self = self else { return }
            let s = c2Model.color.toHexString().suffix(6)
            curSettings.color2 = String(s)
            backgroundModel.color2 = c2Model.color
            backgroundModel.reloadView?()
        }
        
        c3Model.onColorUpdate = { [weak self] in
            guard let self = self else { return }
            let s = c3Model.color.toHexString().suffix(6)
            curSettings.color3 = String(s)
            backgroundModel.color3 = c3Model.color
            backgroundModel.reloadView?()
        }
        
        c4Model.onColorUpdate = { [weak self] in
            guard let self = self else { return }
            let s = c4Model.color.toHexString().suffix(6)
            curSettings.color4 = String(s)
            backgroundModel.color4 = c4Model.color
            backgroundModel.reloadView?()
        }
        
        let colorSec = TableViewSectionModel(title: "Colors", cellModels: [c1Model, c2Model, c3Model, c4Model])
        
        return [gradSec, backSec, colorSec]
    }
    
    func makeSmallMessageSettingsSections() -> [TableViewSectionModel] {
        guard let curSettings = curSettings.activeSettings as? SmallMessageSettings else { return [] }
        
        let modelY = CurveCellModel(theme: theme, duration: curSettings.curveY.duration,
                                              delay: curSettings.curveY.delay,
                                              timings: curSettings.curveY.tuple,
                                              fps: curSettings.durationType.seconds)
        modelY.onUpdate = { [weak self] in
            guard let curSettings = self?.curSettings.activeSettings as? SmallMessageSettings else { return }
            curSettings.curveY = AnimationCurve(tuple: modelY.timings, delay: modelY.delay, duration: modelY.duration)
        }
        let sectionY = TableViewSectionModel(title: "Y position", cellModels: [modelY])
        
        
        
        let modelX = CurveCellModel(theme: theme, duration: curSettings.curveX.duration,
                                              delay: curSettings.curveX.delay,
                                              timings: curSettings.curveX.tuple,
                                              fps: curSettings.durationType.seconds)
        modelX.onUpdate = { [weak self] in
            guard let curSettings = self?.curSettings.activeSettings as? SmallMessageSettings else { return }
            curSettings.curveX = AnimationCurve(tuple: modelX.timings, delay: modelX.delay, duration: modelX.duration)
        }
        let sectionX = TableViewSectionModel(title: "X position", cellModels: [modelX])
        
        
        
        let modelBubble = CurveCellModel(theme: theme, duration: curSettings.curveBubble.duration,
                                              delay: curSettings.curveBubble.delay,
                                              timings: curSettings.curveBubble.tuple,
                                              fps: curSettings.durationType.seconds)
        modelBubble.onUpdate = { [weak self] in
            guard let curSettings = self?.curSettings.activeSettings as? SmallMessageSettings else { return }
            curSettings.curveBubble = AnimationCurve(tuple: modelBubble.timings, delay: modelBubble.delay, duration: modelBubble.duration)
        }
        let sectionBubble = TableViewSectionModel(title: "Bubble", cellModels: [modelBubble])
        
        
        let modelStatus = CurveCellModel(theme: theme, duration: curSettings.curveStatus.duration,
                                              delay: curSettings.curveStatus.delay,
                                              timings: curSettings.curveStatus.tuple,
                                              fps: curSettings.durationType.seconds)
        modelStatus.onUpdate = { [weak self] in
            guard let curSettings = self?.curSettings.activeSettings as? SmallMessageSettings else { return }
            curSettings.curveStatus = AnimationCurve(tuple: modelStatus.timings, delay: modelStatus.delay, duration: modelStatus.duration)
        }
        let sectionStatus = TableViewSectionModel(title: "Status", cellModels: [modelStatus])
        
        return [sectionY, sectionX, sectionBubble, sectionStatus]
    }
    
//    func makeBigMessageSettingsSections() -> [TableViewSectionModel] {
//        guard let curSettings = curSettings.activeSettings as? BigMessageSettings else { return [] }
//
//
//        let modelY = CurveCellModel(theme: theme, duration: curSettings.curveY.duration,
//                                              delay: curSettings.curveY.delay,
//                                              timings: curSettings.curveY.tuple,
//                                              fps: curSettings.durationType.seconds)
//        modelY.onUpdate = { [weak self] in
//            guard let self = self else { return }
//            curSettings.curveY = AnimationCurve(tuple: modelY.timings, delay: modelY.delay, duration: modelY.duration)
//        }
//        let sectionY = TableViewSectionModel(title: "Y position", cellModels: [modelY])
//
//
//
//        let modelX = CurveCellModel(theme: theme, duration: curSettings.curveX.duration,
//                                              delay: curSettings.curveX.delay,
//                                              timings: curSettings.curveX.tuple,
//                                              fps: curSettings.durationType.seconds)
//        modelX.onUpdate = { [weak self] in
//            guard let self = self else { return }
//            curSettings.curveX = AnimationCurve(tuple: modelX.timings, delay: modelX.delay, duration: modelX.duration)
//        }
//        let sectionX = TableViewSectionModel(title: "X position", cellModels: [modelX])
//
//
//
//        let modelBubble = CurveCellModel(theme: theme, duration: curSettings.curveBubble.duration,
//                                              delay: curSettings.curveBubble.delay,
//                                              timings: curSettings.curveBubble.tuple,
//                                              fps: curSettings.durationType.seconds)
//        modelBubble.onUpdate = { [weak self] in
//            guard let self = self else { return }
//            curSettings.curveBubble = AnimationCurve(tuple: modelBubble.timings, delay: modelBubble.delay, duration: modelBubble.duration)
//        }
//        let sectionBubble = TableViewSectionModel(title: "Bubble shape", cellModels: [modelBubble])
//
//
//        let modelText = CurveCellModel(theme: theme, duration: curSettings.curveTextPos.duration,
//                                              delay: curSettings.curveTextPos.delay,
//                                              timings: curSettings.curveTextPos.tuple,
//                                              fps: curSettings.durationType.seconds)
//        modelText.onUpdate = { [weak self] in
//            guard let self = self else { return }
//            curSettings.curveTextPos = AnimationCurve(tuple: modelText.timings, delay: modelText.delay, duration: modelText.duration)
//        }
//        let sectionText = TableViewSectionModel(title: "Text position", cellModels: [modelText])
//
//
//
//        let modelColor = CurveCellModel(theme: theme, duration: curSettings.curveColor.duration,
//                                              delay: curSettings.curveColor.delay,
//                                              timings: curSettings.curveColor.tuple,
//                                              fps: curSettings.durationType.seconds)
//        modelColor.onUpdate = { [weak self] in
//            guard let self = self else { return }
//            curSettings.curveColor = AnimationCurve(tuple: modelColor.timings, delay: modelColor.delay, duration: modelColor.duration)
//        }
//        let sectionColor = TableViewSectionModel(title: "Color change", cellModels: [modelColor])
//
//
//
//        let modelTime = CurveCellModel(theme: theme, duration: curSettings.curveTime.duration,
//                                              delay: curSettings.curveTime.delay,
//                                              timings: curSettings.curveTime.tuple,
//                                              fps: curSettings.durationType.seconds)
//        modelTime.onUpdate = { [weak self] in
//            guard let self = self else { return }
//            curSettings.curveTime = AnimationCurve(tuple: modelTime.timings, delay: modelTime.delay, duration: modelTime.duration)
//        }
//        let sectionTime = TableViewSectionModel(title: "Time appears", cellModels: [modelTime])
//
//
//
//        return [sectionY, sectionX, sectionBubble, sectionText, sectionColor, sectionTime]
//    }
//
//
    
    func makeLinkSettingsSections() -> [TableViewSectionModel] {
        guard let curSettings = curSettings.activeSettings as? LinkWithPreviewSettings else { return [] }
        
        
        let modelY = CurveCellModel(theme: theme, duration: curSettings.curveY.duration,
                                              delay: curSettings.curveY.delay,
                                              timings: curSettings.curveY.tuple,
                                              fps: curSettings.durationType.seconds)
        modelY.onUpdate = { [weak self] in
            guard let self = self else { return }
            curSettings.curveY = AnimationCurve(tuple: modelY.timings, delay: modelY.delay, duration: modelY.duration)
        }
        let sectionY = TableViewSectionModel(title: "Y position", cellModels: [modelY])
        
        
        
        let modelX = CurveCellModel(theme: theme, duration: curSettings.curveX.duration,
                                              delay: curSettings.curveX.delay,
                                              timings: curSettings.curveX.tuple,
                                              fps: curSettings.durationType.seconds)
        modelX.onUpdate = { [weak self] in
            guard let self = self else { return }
            curSettings.curveX = AnimationCurve(tuple: modelX.timings, delay: modelX.delay, duration: modelX.duration)
        }
        let sectionX = TableViewSectionModel(title: "X position", cellModels: [modelX])
        
        
        
//        let modelColor = CurveCellModel(theme: theme, duration: curSettings.curveColor.duration,
//                                              delay: curSettings.curveColor.delay,
//                                              timings: curSettings.curveColor.tuple,
//                                              fps: curSettings.durationType.seconds)
//        modelColor.onUpdate = { [weak self] in
//            guard let self = self else { return }
//            curSettings.curveColor = AnimationCurve(tuple: modelColor.timings, delay: modelColor.delay, duration: modelColor.duration)
//        }
//        let sectionColor = TableViewSectionModel(title: "Color change", cellModels: [modelColor])
        
        
        
        let modelTime = CurveCellModel(theme: theme, duration: curSettings.curveStatus.duration,
                                              delay: curSettings.curveStatus.delay,
                                              timings: curSettings.curveStatus.tuple,
                                              fps: curSettings.durationType.seconds)
        modelTime.onUpdate = { [weak self] in
            guard let self = self else { return }
            curSettings.curveStatus = AnimationCurve(tuple: modelTime.timings, delay: modelTime.delay, duration: modelTime.duration)
        }
        let sectionTime = TableViewSectionModel(title: "Status", cellModels: [modelTime])
        
        
        
        return [sectionY, sectionX, sectionTime]
    }
    
    
    func makeEmojiSettingsSections() -> [TableViewSectionModel] {
        guard let curSettings = curSettings.activeSettings as? EmojiMessageSettings else { return [] }
        
        
        let modelY = CurveCellModel(theme: theme, duration: curSettings.curveY.duration,
                                              delay: curSettings.curveY.delay,
                                              timings: curSettings.curveY.tuple,
                                              fps: curSettings.durationType.seconds)
        modelY.onUpdate = { [weak self] in
            guard let self = self else { return }
            curSettings.curveY = AnimationCurve(tuple: modelY.timings, delay: modelY.delay, duration: modelY.duration)
        }
        let sectionY = TableViewSectionModel(title: "Y position", cellModels: [modelY])
        
        
        
        let modelX = CurveCellModel(theme: theme, duration: curSettings.curveX.duration,
                                              delay: curSettings.curveX.delay,
                                              timings: curSettings.curveX.tuple,
                                              fps: curSettings.durationType.seconds)
        modelX.onUpdate = { [weak self] in
            guard let self = self else { return }
            curSettings.curveX = AnimationCurve(tuple: modelX.timings, delay: modelX.delay, duration: modelX.duration)
        }
        let sectionX = TableViewSectionModel(title: "X position", cellModels: [modelX])
        
        
        
        let modelScale = CurveCellModel(theme: theme, duration: curSettings.curveScale.duration,
                                              delay: curSettings.curveScale.delay,
                                              timings: curSettings.curveScale.tuple,
                                              fps: curSettings.durationType.seconds)
        modelScale.onUpdate = { [weak self] in
            guard let self = self else { return }
            curSettings.curveScale = AnimationCurve(tuple: modelScale.timings, delay: modelScale.delay, duration: modelScale.duration)
        }
        let sectionScale = TableViewSectionModel(title: "Emoji scale", cellModels: [modelScale])
        
        
        
        let modelTime = CurveCellModel(theme: theme, duration: curSettings.curveStatus.duration,
                                              delay: curSettings.curveStatus.delay,
                                              timings: curSettings.curveStatus.tuple,
                                              fps: curSettings.durationType.seconds)
        modelTime.onUpdate = { [weak self] in
            guard let self = self else { return }
            curSettings.curveStatus = AnimationCurve(tuple: modelTime.timings, delay: modelTime.delay, duration: modelTime.duration)
        }
        let sectionTime = TableViewSectionModel(title: "Status", cellModels: [modelTime])
        
        
        
        return [sectionY, sectionX, sectionScale, sectionTime]
    }
    
    
    func makeStickerSettingsSections() -> [TableViewSectionModel] {
        guard let curSettings = curSettings.activeSettings as? StickerMessageSettings else { return [] }
        
        
        let modelY = CurveCellModel(theme: theme, duration: curSettings.curveY.duration,
                                              delay: curSettings.curveY.delay,
                                              timings: curSettings.curveY.tuple,
                                              fps: curSettings.durationType.seconds)
        modelY.onUpdate = { [weak self] in
            guard let self = self else { return }
            curSettings.curveY = AnimationCurve(tuple: modelY.timings, delay: modelY.delay, duration: modelY.duration)
        }
        let sectionY = TableViewSectionModel(title: "Y position", cellModels: [modelY])
        
        
        
        let modelX = CurveCellModel(theme: theme, duration: curSettings.curveX.duration,
                                              delay: curSettings.curveX.delay,
                                              timings: curSettings.curveX.tuple,
                                              fps: curSettings.durationType.seconds)
        modelX.onUpdate = { [weak self] in
            guard let self = self else { return }
            curSettings.curveX = AnimationCurve(tuple: modelX.timings, delay: modelX.delay, duration: modelX.duration)
        }
        let sectionX = TableViewSectionModel(title: "X position", cellModels: [modelX])
        
        
        
        let modelScale = CurveCellModel(theme: theme, duration: curSettings.curveScale.duration,
                                              delay: curSettings.curveScale.delay,
                                              timings: curSettings.curveScale.tuple,
                                              fps: curSettings.durationType.seconds)
        modelScale.onUpdate = { [weak self] in
            guard let self = self else { return }
            curSettings.curveScale = AnimationCurve(tuple: modelScale.timings, delay: modelScale.delay, duration: modelScale.duration)
        }
        let sectionScale = TableViewSectionModel(title: "Sticker scale", cellModels: [modelScale])
        
        
        
        let modelTime = CurveCellModel(theme: theme, duration: curSettings.curveStatus.duration,
                                              delay: curSettings.curveStatus.delay,
                                              timings: curSettings.curveStatus.tuple,
                                              fps: curSettings.durationType.seconds)
        modelTime.onUpdate = { [weak self] in
            guard let self = self else { return }
            curSettings.curveStatus = AnimationCurve(tuple: modelTime.timings, delay: modelTime.delay, duration: modelTime.duration)
        }
        let sectionTime = TableViewSectionModel(title: "Status", cellModels: [modelTime])
        
        
        
        return [sectionY, sectionX, sectionScale, sectionTime]
    }
    
    
    
    
    func makeVoiceSettingsSections() -> [TableViewSectionModel] {
        guard let curSettings = curSettings.activeSettings as? VoiceMessageSettings else { return [] }
        
        
        let modelY = CurveCellModel(theme: theme, duration: curSettings.curveY.duration,
                                              delay: curSettings.curveY.delay,
                                              timings: curSettings.curveY.tuple,
                                              fps: curSettings.durationType.seconds)
        modelY.onUpdate = { [weak self] in
            guard let self = self else { return }
            curSettings.curveY = AnimationCurve(tuple: modelY.timings, delay: modelY.delay, duration: modelY.duration)
        }
        let sectionY = TableViewSectionModel(title: "Y position", cellModels: [modelY])
        
        
        
        let modelX = CurveCellModel(theme: theme, duration: curSettings.curveX.duration,
                                              delay: curSettings.curveX.delay,
                                              timings: curSettings.curveX.tuple,
                                              fps: curSettings.durationType.seconds)
        modelX.onUpdate = { [weak self] in
            guard let self = self else { return }
            curSettings.curveX = AnimationCurve(tuple: modelX.timings, delay: modelX.delay, duration: modelX.duration)
        }
        let sectionX = TableViewSectionModel(title: "X position", cellModels: [modelX])
        
        
//        let modelScale = CurveCellModel(theme: theme, duration: curSettings.curveScale.duration,
//                                              delay: curSettings.curveScale.delay,
//                                              timings: curSettings.curveScale.tuple,
//                                              fps: curSettings.durationType.seconds)
//        modelScale.onUpdate = { [weak self] in
//            guard let self = self else { return }
//            curSettings.curveScale = AnimationCurve(tuple: modelScale.timings, delay: modelScale.delay, duration: modelScale.duration)
//        }
//        let sectionScale = TableViewSectionModel(title: "Scale", cellModels: [modelScale])
//
//
//
        let modelTime = CurveCellModel(theme: theme, duration: curSettings.curveStatus.duration,
                                              delay: curSettings.curveStatus.delay,
                                              timings: curSettings.curveStatus.tuple,
                                              fps: curSettings.durationType.seconds)
        modelTime.onUpdate = { [weak self] in
            guard let self = self else { return }
            curSettings.curveStatus = AnimationCurve(tuple: modelTime.timings, delay: modelTime.delay, duration: modelTime.duration)
        }
        let sectionTime = TableViewSectionModel(title: "Status", cellModels: [modelTime])
        
        
        
        return [sectionY, sectionX ,sectionTime]
    }
    
    
    func makeVideoSettingsSections() -> [TableViewSectionModel] {
        guard let curSettings = curSettings.activeSettings as? VideoMessageSettings else { return [] }
        
        
        let modelY = CurveCellModel(theme: theme, duration: curSettings.curveY.duration,
                                              delay: curSettings.curveY.delay,
                                              timings: curSettings.curveY.tuple,
                                              fps: curSettings.durationType.seconds)
        modelY.onUpdate = { [weak self] in
            guard let self = self else { return }
            curSettings.curveY = AnimationCurve(tuple: modelY.timings, delay: modelY.delay, duration: modelY.duration)
        }
        let sectionY = TableViewSectionModel(title: "Y position", cellModels: [modelY])
        
        
        
        let modelX = CurveCellModel(theme: theme, duration: curSettings.curveX.duration,
                                              delay: curSettings.curveX.delay,
                                              timings: curSettings.curveX.tuple,
                                              fps: curSettings.durationType.seconds)
        modelX.onUpdate = { [weak self] in
            guard let self = self else { return }
            curSettings.curveX = AnimationCurve(tuple: modelX.timings, delay: modelX.delay, duration: modelX.duration)
        }
        let sectionX = TableViewSectionModel(title: "X position", cellModels: [modelX])
        
        
        
        let modelScale = CurveCellModel(theme: theme, duration: curSettings.curveScale.duration,
                                              delay: curSettings.curveScale.delay,
                                              timings: curSettings.curveScale.tuple,
                                              fps: curSettings.durationType.seconds)
        modelScale.onUpdate = { [weak self] in
            guard let self = self else { return }
            curSettings.curveScale = AnimationCurve(tuple: modelScale.timings, delay: modelScale.delay, duration: modelScale.duration)
        }
        let sectionScale = TableViewSectionModel(title: "Scale", cellModels: [modelScale])
        
        
        let modelTime = CurveCellModel(theme: theme, duration: curSettings.curveStatus.duration,
                                              delay: curSettings.curveStatus.delay,
                                              timings: curSettings.curveStatus.tuple,
                                              fps: curSettings.durationType.seconds)
        modelTime.onUpdate = { [weak self] in
            guard let self = self else { return }
            curSettings.curveStatus = AnimationCurve(tuple: modelTime.timings, delay: modelTime.delay, duration: modelTime.duration)
        }
        let sectionTime = TableViewSectionModel(title: "Status", cellModels: [modelTime])
        
        
        
        return [sectionY, sectionX, sectionScale, sectionTime]
    }
}


fileprivate extension UIView {
    private struct AssociatedKey {
        static var subviewsBackgroundColor = "subviewsBackgroundColor"
    }
    
    @objc dynamic var subviewsBackgroundColor: UIColor? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKey.subviewsBackgroundColor) as? UIColor
        }
        
        set {
            objc_setAssociatedObject(self,
                                     &AssociatedKey.subviewsBackgroundColor,
                                     newValue,
                                     .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            subviews.forEach { $0.backgroundColor = newValue }
        }
    }
}
