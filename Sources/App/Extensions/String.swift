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

    private static var emailRegex: NSRegularExpression = {
        // https://stackoverflow.com/a/41782027/3905537
        let firstpart = "[A-Z0-9a-z]([A-Z0-9a-z._%+-]{0,30}[A-Z0-9a-z])?"
        let serverpart = "([A-Z0-9a-z]([A-Z0-9a-z-]{0,30}[A-Z0-9a-z])?\\.){1,5}"
        let emailRegex = "^\(firstpart)@\(serverpart)[A-Za-z]{2,8}$"
        return try! NSRegularExpression(pattern: emailRegex, options: .caseInsensitive)
    }()

    var isValidEmail: Bool {
        let res = Self.emailRegex.firstMatch(in: self, options: [], range: NSRange(location: 0, length: count))
        return res != nil
    }

    static let validchars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890-=!@#$%^&*()_+<>/\\;:'\"[]{}~`"
    static let uppers = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    static let lowers = "abcdefghijklmnopqrstuvwxyz"
    static let numbers = "1234567890"
    static let chars = "-=!@#$%^&*()_+<>/\\;:'\"[]{}~`"

    var isValidPassword: Bool {
        guard self.count >= 8,
              self.reduce(true, { $0 && Self.validchars.contains($1) } ) else {
            return false
        }

        let hasUppers = self.reduce(false, { $0 || Self.uppers.contains($1) } )
        let hasLowers = self.reduce(false, { $0 || Self.lowers.contains($1) } )
        let hasNumbers = self.reduce(false, { $0 || Self.numbers.contains($1) } )
        let hasChars = self.reduce(false, { $0 || Self.chars.contains($1) } )

        let score = (hasUppers ? 1 : 0)
                  + (hasLowers ? 1 : 0)
                  + (hasNumbers ? 1 : 0)
                  + (hasChars ? 1 : 0)

        guard score >= 3 else {
            return false
        }

        return true
    }
}
