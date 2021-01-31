//
//  SettingsTypeController.swift
//  settingsui
//
//  Created by Nikita Rostovskii on 25.01.2021.
//

import UIKit

final class SettingsTypeController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    
    private var tableView: UITableView!
    
    public var onSelect: ((Int) -> Void)?
    
    private var models: [ActionCellModel] = []
    
    var theme: AnimationsTheme?
    
    private func makeModels() {
        guard let theme = theme else { return }
        self.models = [
            ActionCellModel(theme: theme, title: "Text Message", color: .action),
//            ActionCellModel(theme: theme, title: "Big Message (doesn't fit into the input field)", color: .action),
            ActionCellModel(theme: theme, title: "Link with Preview", color: .action),
            ActionCellModel(theme: theme, title: "Single Emoji", color: .action),
            ActionCellModel(theme: theme, title: "Sticker", color: .action),
            ActionCellModel(theme: theme, title: "Voice Message", color: .action),
            ActionCellModel(theme: theme, title: "Video Message", color: .action),
            ActionCellModel(theme: theme, title: "Background", color: .action),
        ]
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        makeModels()
        
        navigationItem.title = "Animation Type"
        
        self.tableView = UITableView(frame: view.bounds, style: .grouped)
        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.tableView.delaysContentTouches = false
        tableView.register(ActionCell.self, forCellReuseIdentifier: String(describing: ActionCell.self))
        self.view.addSubview(self.tableView)
        
        
        guard let theme = theme else { return }
        view.backgroundColor = theme.background
        tableView.backgroundColor = theme.background
        tableView.separatorColor = theme.separator
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = view.bounds
    }
    
    public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return "Messages"
        } else {
            return "Other"
        }
    }

    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 6
        } else {
            return 1
        }
    }
    
    public func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: ActionCell.self)) as? ActionCell
        else { return UITableViewCell() }
        
        let i = (indexPath.section == 0 ? 0 : 6) + indexPath.row
        guard i >= 0, i < models.count else { return UITableViewCell() }
        cell.setup(with: models[i])
        
        return cell
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let i = (indexPath.section == 0 ? 0 : 6) + indexPath.row
        onSelect?(i)
        navigationController?.popViewController(animated: true)
    }
    
    
    public func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let header = view as! UITableViewHeaderFooterView
        header.textLabel?.textColor = theme?.sectionTitleColor
    }
}
