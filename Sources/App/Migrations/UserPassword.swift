//
//  UserPassword.swift
//  
//
//  Created by Вадим Балашов on 29.03.2021.
//

import Fluent

struct UserPassword: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(User.schema)
            .field("password", .string, .required)
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(User.schema)
            .deleteField("password")
            .delete()
    }
}

