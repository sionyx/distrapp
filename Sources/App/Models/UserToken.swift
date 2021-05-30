//
//  UserToken.swift
//  
//
//  Created by Вадим Балашов on 06.09.2020.
//

import Fluent
import Vapor

final class UserToken: Model {
    static let schema = "user_tokens"

    @ID(key: .id)
    var id: UUID?

    @Timestamp(key: "created", on: .create)
    var created: Date?

    @Field(key: "value")
    var value: String

    @Field(key: "place")
    var place: String

    @Parent(key: "user_id")
    var user: User


    init() { }

    init(id: UUID? = nil, value: String, place: String, userID: User.IDValue, created: Date? = nil) {
        self.id = id
        self.value = value
        self.place = place
        self.created = created
        self.$user.id = userID
    }
}

extension UserToken: ModelTokenAuthenticatable {
    static let valueKey = \UserToken.$value
    static let userKey = \UserToken.$user

    var isValid: Bool {
        true
    }
}

extension UserToken {
    struct Short: Content {
        let token: String
        let place: String

        fileprivate init(_ userToken: UserToken) {
            self.token = userToken.value
            self.place = userToken.place
        }
    }

    var short: Short {
        Short(self)
    }
}

extension UserToken {
    struct Secure: Content {
        let id: String
        let full: String?
        let token: String
        let place: String

        fileprivate init?(_ userToken: UserToken) {
            guard let id = userToken.id?.uuidString,
                  let created = userToken.created else { return nil }
            self.id = id
            self.full = Date().timeIntervalSince(created) < 300 ? userToken.value : nil
            self.token = "\(userToken.value.prefix(4))...\(userToken.value.suffix(4))"
            self.place = userToken.place
        }
    }

    var secure: Secure? {
        Secure(self)
    }
}
