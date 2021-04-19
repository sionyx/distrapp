//
//  UserTokensController.swift
//  
//
//  Created by Вадим Балашов on 29.12.2020.
//

import Fluent
import Vapor

struct UserTokensController {
    // http://localhost:8080/tokens
    func _index(req: Request) throws -> EventLoopFuture<[UserToken.Short]> {
        return UserToken.query(on: req.db).all().mapEach { $0.short }
    }
}
