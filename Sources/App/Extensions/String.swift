//
//  File.swift
//  
//
//  Created by Вадим Балашов on 01.02.2021.
//

import Foundation

extension String {
    var nonEmptyValue: String? {
        guard count > 0 else {
            return nil
        }
        return self
    }
}
