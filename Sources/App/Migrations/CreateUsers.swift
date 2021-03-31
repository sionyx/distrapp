//
//  CreateUsers.swift
//  
//
//  Created by Вадим Балашов on 23.08.2020.
//

import Fluent

struct CreateUsers: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(User.schema)
            .id()
            .field("created", .datetime, .required)
            .field("updated", .datetime, .required)
            .field("first_name", .string, .required)
            .field("last_name", .string, .required)
            .field("user_pic", .string)
            .field("auth_provider", .string, .required)
            .field("auth_id", .string, .required)
            .unique(on: "auth_provider", "auth_id")
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(User.schema).delete()
    }
}

