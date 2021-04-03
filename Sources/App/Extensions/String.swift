//
//  File.swift
//  
//
//  Created by Вадим Балашов on 01.02.2021.
//

import Foundation

extension String {
    var nonEmptyValue: String? {
        guard !isEmpty else {
            return nil
        }
        return self
    }

    var isValidEmail: Bool {
        let regex = try! NSRegularExpression(pattern: "^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$", options: .caseInsensitive)
        return regex.firstMatch(in: self, options: [], range: NSRange(location: 0, length: count)) != nil
    }

    static let validchars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890-=!@#$%^&*()_+<>/\\;:'\"[]{}~`"
    var isValidPassword: Bool {
        guard self.count >= 8,
              self.reduce(true, { $0 && Self.validchars.contains($1) } ) else {
            return false
        }

        return true
    }
}
