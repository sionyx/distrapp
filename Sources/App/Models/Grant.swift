//
//  Grant.swift
//  
//
//  Created by Вадим Балашов on 23.08.2020.
//

import Fluent
import Vapor

enum GrantType: String, Codable {
    case view
    case test
    case upload
    case owner

    var canUpload: Bool {
        switch self {
        case .owner, .upload:
            return true
        default:
            return false
        }
    }

    var canTest: Bool {
        switch self {
        case .owner, .upload, .test:
            return true
        default:
            return false
        }
    }
}

final class Grant: Model {
    static let schema = "grants"

    @ID(key: .id)
    var id: UUID?

    @Timestamp(key: "created", on: .create)
    var created: Date?

    @Timestamp(key: "updated", on: .update)
    var updated: Date?

    @Parent(key: "project_id")
    var project: Project

    @Parent(key: "user_id")
    var user: User

    @Field(key: "type")
    var type: GrantType


    init() { }

    init(id: UUID? = nil, project: Project, user: User, type: GrantType) throws {
        self.id = id
        self.$project.id = try project.requireID()
        self.$user.id = try user.requireID()
        self.type = type
    }
}

extension Grant {
    struct Short: Content {
        let user: String
        let project: String
        let type: GrantType?

        fileprivate init(_ grant: Grant) {
            self.user = grant.user.authId
            self.project = grant.project.name
            self.type = grant.type
        }
    }

    var short: Short {
        Short(self)
    }
}
