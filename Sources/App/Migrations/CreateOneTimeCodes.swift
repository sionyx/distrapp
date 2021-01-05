//
//  CreateOneTimeCodes.swift
//  
//
//  Created by Вадим Балашов on 18.12.2020.
//

import Fluent

struct CreateOneTimeCodes: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(OneTimeCode.schema)
            .id()
            .field("created", .datetime, .required)
            .field("value", .string, .required)
            .field("email", .string, .required)
            .unique(on: "email")
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(OneTimeCode.schema).delete()
    }
}
