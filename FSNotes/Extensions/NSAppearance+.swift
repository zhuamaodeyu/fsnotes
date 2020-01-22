//
//  NSAppearance+.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 9/29/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import AppKit.NSAppearance

extension NSAppearance {
    
    /// 是否是黑暗模式
    /*
     aqua: 标准外观
     darkAqua: 标准深色
     vibrantLight: 轻盈外观，仅在 visual effect 中有用
     ...
     带有 dark 的都是黑暗模式 
    */
    var isDark: Bool {
        if self.name == .vibrantDark { return true }

        guard #available(macOS 10.14, *) else { return false }

        switch self.name {
        case .accessibilityHighContrastDarkAqua,
             .darkAqua,
             .accessibilityHighContrastVibrantDark:
            return true
        default:
            return false
        }
    }
}
