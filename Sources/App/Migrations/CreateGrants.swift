//
//  File.swift
//  
//
//  Created by Вадим Балашов on 23.08.2020.
//

import Fluent

struct CreateGrants: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("grants")
            .id()
            .field("created", .datetime, .required)
            .field("updated", .datetime, .required)
            .field("project_id", .uuid, .required, .references("projects", "id"))
            .field("user_id", .uuid, .required, .references("users", "id"))
            .field("type", .string, .required)
            .unique(on: "project_id", "user_id")
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("grants").delete()
    }
}
