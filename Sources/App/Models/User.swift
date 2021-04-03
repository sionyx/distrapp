//
//  User.swift
//  
//
//  Created by Вадим Балашов on 23.08.2020.
//

import Fluent
import Vapor

final class User: Model {
    static let schema = "users"

    @ID(key: .id)
    var id: UUID?

    @Timestamp(key: "created", on: .create)
    var created: Date?

    @Timestamp(key: "updated", on: .update)
    var updated: Date?

    @Field(key: "first_name")
    var firstName: String

    @Field(key: "last_name")
    var lastName: String

    @OptionalField(key: "user_pic")
    var userPic: String?

    @Field(key: "auth_provider")
    var authProvider: String

    @Field(key: "auth_id")
    var authId: String

    @Field(key: "password")
    var password: String

    @Siblings(through: Grant.self, from: \.$user, to: \.$project)
    public var projects: [Project]

    init() { }

    init(id: UUID? = nil, firstName: String, lastName: String, authProvider: String, authId: String, password: String, userPic: String? = nil, created: Date? = nil, updated: Date? = nil) {
        self.id = id
        self.created = created
        self.updated = updated
        self.firstName = firstName
        self.lastName = lastName
        self.password = password
        self.userPic = userPic
        self.authProvider = authProvider
        self.authId = authId
    }

}

extension User {
    func generateToken(place: String) throws -> UserToken {
        try UserToken(value: (0..<64).map { _ in Int.random(in: 0...15) }.reduce("") { $0 + String(format:"%01X", $1) },
                  place: place,
                  userID: self.requireID()
        )
    }
}

extension User {
    struct Short: Content {
        let firstName: String
        let lastName: String
        let userPic: String?
        let authProvider: String
        let authId: String

        fileprivate init(_ user: User) {
            self.firstName = user.firstName
            self.lastName = user.lastName
            self.userPic = user.userPic
            self.authProvider = user.authProvider
            self.authId = user.authId
        }

        private enum CodingKeys: String, CodingKey {
            case firstName = "first_name"
            case lastName = "last_name"
            case userPic = "user_pic"
            case authProvider = "provider"
            case authId = "id"
        }
    }

    var short: Short {
        Short(self)
    }
}

extension User {
    static func by(name: String, on db: Database) -> EventLoopFuture<User> {
        User.query(on: db)
            .filter(\.$authId == name)
            .first()
            .unwrap(or: Abort(.notFound, reason: "User Not Found"))
            .guard({ $0.id != nil }, else: Abort(.internalServerError, reason: "User Has No Id"))
    }
}

// MARK: - Authenication

extension User: Authenticatable {}
extension User: ModelSessionAuthenticatable { }

extension User: ModelCredentialsAuthenticatable {
    static let usernameKey = \User.$authId
    static let passwordHashKey = \User.$password

    func verify(password: String) throws -> Bool {
        if self.password == "" {
            return true
        }
        
        _ = try Bcrypt.verify(password, created: self.password)
        return true
    }
}
