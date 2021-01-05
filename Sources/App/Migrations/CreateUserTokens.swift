//
//  File.swift
//  
//
//  Created by Вадим Балашов on 06.09.2020.
//

import Fluent

struct CreateUserToken: Fluent.Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(UserToken.schema)
            .id()
            .field("created", .datetime, .required)
            .field("value", .string, .required)
            .field("place", .string, .required)
            .field("user_id", .uuid, .required, .references("users", "id"))
            .unique(on: "value")
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(UserToken.schema).delete()
    }
}
