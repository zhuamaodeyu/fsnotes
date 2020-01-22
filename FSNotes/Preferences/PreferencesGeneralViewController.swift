//
//  PreferencesGeneralViewController.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 3/17/19.
//  Copyright © 2019 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa
import MASShortcut
import CoreData
import FSNotesCore_macOS

class PreferencesGeneralViewController: NSViewController {
    override func viewWillAppear() {
        super.viewWillAppear()
        // 表示当前视图的大小，在布局时， 父视图可能会询问
        preferredContentSize = NSSize(width: 476, height: 413)
    }
    
    // 外部编辑器打开
    @IBOutlet var externalEditorApp: NSTextField!
    
    // 快捷键
    @IBOutlet var newNoteshortcutView: MASShortcutView!
    @IBOutlet var searchNotesShortcut: MASShortcutView!
    // 存储位置控件
    @IBOutlet weak var defaultStoragePath: NSPathControl!
    
    @IBOutlet weak var showDockIcon: NSButton!
    @IBOutlet weak var txtAsMarkdown: NSButton!
    @IBOutlet weak var showInMenuBar: NSButton!
    @IBOutlet weak var fileFormat: NSPopUpButton!
    @IBOutlet weak var fileContainer: NSPopUpButton!

    //MARK: global variables
    
    let storage = Storage.sharedInstance()

    override func viewDidLoad() {
        super.viewDidLoad()
        initShortcuts()
    }

    override func viewDidAppear() {
        // 设置 titile
        self.view.window!.title = NSLocalizedString("Preferences", comment: "")

        externalEditorApp.stringValue = UserDefaultsManagement.externalEditor

        if let url = UserDefaultsManagement.storageUrl {
            defaultStoragePath.stringValue = url.path
        }

        showDockIcon.state = UserDefaultsManagement.showDockIcon ? .on : .off

        txtAsMarkdown.state = UserDefaultsManagement.txtAsMarkdown ? .on : .off

        showInMenuBar.state = UserDefaultsManagement.showInMenuBar ? .on : .off

        fileFormat.selectItem(withTag: UserDefaultsManagement.fileFormat.tag)

        fileContainer.selectItem(withTag: UserDefaultsManagement.fileContainer.tag)
    }

    @IBAction func changeDefaultStorage(_ sender: Any) {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = true
        openPanel.canChooseFiles = false
        openPanel.begin { (result) -> Void in
            if result.rawValue == NSFileHandlingPanelOKButton {
                guard let url = openPanel.url else { return }
                guard let currentURL = UserDefaultsManagement.storageUrl else { return }

                let bookmark = SandboxBookmark.sharedInstance()
                let activeBookmars = bookmark.load()
                bookmark.remove(url: currentURL)
                bookmark.store(url: url)
                bookmark.save()

                UserDefaultsManagement.storagePath = url.path
                self.defaultStoragePath.stringValue = url.path

                // Resets archive if not bookmarked
                if let archiveURL = UserDefaultsManagement.archiveDirectory, !activeBookmars.contains(archiveURL) {
                    UserDefaultsManagement.archiveDirectory = nil
                }

                self.restart()
            }
        }
    }

    @IBAction func externalEditor(_ sender: Any) {
        UserDefaultsManagement.externalEditor = externalEditorApp.stringValue
    }

    func restart() {
        let url = URL(fileURLWithPath: Bundle.main.resourcePath!)
        let path = url.deletingLastPathComponent().deletingLastPathComponent().absoluteString
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = [path]
        task.launch()
        exit(0)
    }

    func initShortcuts() {
        guard let vc = ViewController.shared() else { return }

        let mas = MASShortcutMonitor.shared()

        newNoteshortcutView.shortcutValue = UserDefaultsManagement.newNoteShortcut
        searchNotesShortcut.shortcutValue = UserDefaultsManagement.searchNoteShortcut

        newNoteshortcutView.shortcutValueChange = { (sender) in
            if ((self.newNoteshortcutView.shortcutValue) != nil) {
                mas?.unregisterShortcut(UserDefaultsManagement.newNoteShortcut)

                let keyCode = self.newNoteshortcutView.shortcutValue.keyCode
                let modifierFlags = self.newNoteshortcutView.shortcutValue.modifierFlags

                UserDefaultsManagement.newNoteShortcut = MASShortcut(keyCode: keyCode, modifierFlags: modifierFlags)

                MASShortcutMonitor.shared().register(self.newNoteshortcutView.shortcutValue, withAction: {
                    vc.makeNoteShortcut()
                })
            }
        }

        searchNotesShortcut.shortcutValueChange = { (sender) in
            if ((self.searchNotesShortcut.shortcutValue) != nil) {
                mas?.unregisterShortcut(UserDefaultsManagement.searchNoteShortcut)

                let keyCode = self.searchNotesShortcut.shortcutValue.keyCode
                let modifierFlags = self.searchNotesShortcut.shortcutValue.modifierFlags

                UserDefaultsManagement.searchNoteShortcut = MASShortcut(keyCode: keyCode, modifierFlags: modifierFlags)

                MASShortcutMonitor.shared().register(self.searchNotesShortcut.shortcutValue, withAction: {
                    vc.searchShortcut()
                })
            }
        }
    }

    @IBAction func showDockIcon(_ sender: NSButton) {
        let isEnabled = sender.state == .on
        UserDefaultsManagement.showDockIcon = isEnabled
        
        // 修改了程序激活策略   regular ： 出现在Dock中的普通程序，可能存在用户界面
        // accessory: 没有出现在dock， 也没有菜单栏， 但可以通过编程方式或通过单击窗口之一激活
        // prohibited: 改应用程序不会出现在Dock， 并且可能不会创建窗口或被激活
        NSApp.setActivationPolicy(isEnabled ? .regular : .accessory)
        
        // 此处关闭Dock:
            // 顶部没有 menu 并且 dock 也没有对应程序
        DispatchQueue.main.async {
            NSMenu.setMenuBarVisible(true)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @IBAction func txtAsMarkdown(_ sender: NSButton) {
        UserDefaultsManagement.txtAsMarkdown = sender.state == .on
    }
    
    // 是否在顶部显示对应的图标
    @IBAction func showInMenuBar(_ sender: NSButton) {
        UserDefaultsManagement.showInMenuBar = sender.state == .on

        guard let appDelegate = NSApplication.shared.delegate as? AppDelegate else { return }

        if sender.state == .off {
            appDelegate.removeMenuBar(nil)
            return
        }
        
        appDelegate.addMenuBar(nil)
    }

    @IBAction func fileFormat(_ sender: NSPopUpButton) {
        guard let item = sender.selectedItem else { return }

        UserDefaultsManagement.fileFormat = NoteType.withTag(rawValue: item.tag)
    }

    @IBAction func fileContainer(_ sender: NSPopUpButton) {
        guard let item = sender.selectedItem else { return }

        if let container = NoteContainer(rawValue: item.tag) {
            UserDefaultsManagement.fileContainer = container
        }
    }
}
