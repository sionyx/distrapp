//
//  OneTimeCode.swift
//  
//
//  Created by Вадим Балашов on 18.12.2020.
//

import Fluent
import Vapor

final class OneTimeCode: Model {
    static let schema = "one_time_codes"

    @ID(key: .id)
    var id: UUID?

    @Timestamp(key: "created", on: .create)
    var created: Date?

    @Field(key: "value")
    var value: String

    @Field(key: "email")
    var email: String

    init() { }

    init(id: UUID? = nil, value: String, email: String, created: Date? = nil) {
        self.id = id
        self.value = value
        self.email = email
        self.created = created
    }

    func withValue(_ value: String) -> Self {
        self.value = value
        return self
    }
}
