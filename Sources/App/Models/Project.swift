//
//  Project.swift
//  
//
//  Created by Вадим Балашов on 21.08.2020.
//

import Fluent
import Vapor

final class Project: Model {
    static let schema = "projects"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @Timestamp(key: "created", on: .create)
    var created: Date?

    @Timestamp(key: "updated", on: .update)
    var updated: Date?

    @Field(key: "title")
    var title: String

    @Field(key: "bundle_id")
    var bundleId: String

    @OptionalField(key: "description")
    var description: String?

    @OptionalField(key: "icon")
    var icon: String?

    @OptionalField(key: "telegram_token")
    var telegramToken: String?

    @OptionalField(key: "telegram_id")
    var telegramId: String?

    @OptionalField(key: "myteam_token")
    var myteamToken: String?

    @OptionalField(key: "myteam_url")
    var myteamUrl: String?

    @OptionalField(key: "myteam_id")
    var myteamId: String?

    @Children(for: \.$project)
    var branches: [Branch]

    @Siblings(through: Grant.self, from: \.$project, to: \.$user)
    var users: [User]


    init() { }

    init(id: UUID? = nil, name: String, title: String, bundleId: String, description: String?, icon: String?, telegramToken: String? = nil, telegramId: String? = nil, myteamToken: String? = nil, myteamUrl: String? = nil, myteamId: String? = nil, created: Date? = nil, updated: Date? = nil) {
        self.id = id
        self.name = name
        self.created = created
        self.updated = updated
        self.title = title
        self.bundleId = bundleId
        self.description = description
        self.icon = icon
        self.telegramToken = telegramToken
        self.telegramId = telegramId
        self.myteamToken = myteamToken
        self.myteamUrl = myteamUrl
        self.myteamId = myteamId
    }
}

extension Project {
    struct Short: Content {
        let name: String
        let title: String
        let bundleId: String
        let description: String?
        let icon: String?
        let telegramToken: String?
        let telegramId: String?
        let myteamToken: String?
        let myteamUrl: String?
        let myteamId: String?
        let grant: GrantType?
        let role: String?

        fileprivate init(_ project: Project, grant: GrantType? = nil) {
            self.name = project.name
            self.title = project.title
            self.bundleId = project.bundleId
            self.description = project.description?.nonEmptyValue
            self.icon = project.icon
            self.telegramToken = project.telegramToken
            self.telegramId = project.telegramId
            self.myteamToken = project.myteamToken
            self.myteamUrl = project.myteamUrl
            self.myteamId = project.myteamId
            self.grant = grant
            self.role = grant?.role
        }
        
        private enum CodingKeys: String, CodingKey {
            case name
            case title
            case bundleId = "bundle_id"
            case description
            case icon
            case telegramToken = "telegram_token"
            case telegramId = "telegram_id"
            case myteamToken = "myteam_token"
            case myteamUrl = "myteam_url"
            case myteamId = "myteam_id"
            case grant
            case role
        }

        var long: Project {
            Project(name: name,
                    title: title,
                    bundleId: bundleId,
                    description: description,
                    icon: icon,
                    telegramToken: telegramToken,
                    telegramId: telegramId,
                    myteamToken: myteamToken,
                    myteamUrl: myteamUrl,
                    myteamId: myteamId)
        }
    }

    var short: Short {
        Short(self)
    }

    func short(with grant: GrantType) -> Short {
        Short(self, grant: grant)
    }
}

extension Project {
    static func by(name: String, on db: Database) -> EventLoopFuture<Project> {
        Project.query(on: db)
            .filter(\.$name == name)
            .first()
            .unwrap(or: Abort(.notFound, reason: "Project Not Found"))
            .guard({ $0.id != nil }, else: Abort(.internalServerError, reason: "Project Has No Id"))
    }
}

extension EventLoopFuture where Value == Project {
    func granted(to userId: UUID, on db: Database) -> EventLoopFuture<(Project, GrantType)> {
        self
            .guard({ $0.id != nil }, else: Abort(.internalServerError, reason: "Project Has No Id"))
            .flatMap { project -> EventLoopFuture<(Project, GrantType)> in
                return Grant.query(on: db)
                    .group(.and) { group in
                        group
                            .filter(\.$user.$id == userId)
                            .filter(\.$project.$id == project.id!)
                    }
                    .first()
                    .unwrap(or: Abort(.notFound))
                    .map { (project, $0.type) }
            }
    }

    func grantedOrNot(to userId: UUID?, on db: Database) -> EventLoopFuture<(Project, GrantType?)> {
        guard let userId = userId else {
            return self.map { ($0, nil) }
        }

        return self
            .guard({ $0.id != nil }, else: Abort(.internalServerError, reason: "Project Has No Id"))
            .flatMap { project -> EventLoopFuture<(Project, GrantType?)> in
                return Grant.query(on: db)
                    .group(.and) { group in
                        group
                            .filter(\.$user.$id == userId)
                            .filter(\.$project.$id == project.id!)
                    }
                    .first()
                    .map { (project, $0?.type) }
            }
    }
}

extension EventLoopFuture where Value == (Project, GrantType) {
    /// Checks access to invite
    func canInvite() -> EventLoopFuture<(Project, GrantType)> {
        self
            .guard({ $0.1.canInvite }, else: Abort(.forbidden, reason: "No Permisions To Invite"))
            .map { $0 }
    }

    /// Checks access to edit project
    func canEdit() -> EventLoopFuture<(Project, GrantType)> {
        self
            .guard({ $0.1.canEdit }, else: Abort(.forbidden, reason: "No Permisions To Delete"))
            .map { $0 }
    }


    /// Checks access to delete
    func canDelete() -> EventLoopFuture<(Project, GrantType)> {
        self
            .guard({ $0.1.canDelete }, else: Abort(.forbidden, reason: "No Permisions To Delete"))
            .map { $0 }
    }

    /// Checks access to protect
    func canProtect() -> EventLoopFuture<(Project, GrantType)> {
        self
            .guard({ $0.1.canProtect }, else: Abort(.forbidden, reason: "No Permisions To Protect"))
            .map { $0 }
    }

    /// Checks access to upload
    func canUpload() -> EventLoopFuture<(Project, GrantType)> {
        self
            .guard({ $0.1.canUpload }, else: Abort(.forbidden, reason: "No Permisions To Upload"))
            .map { $0 }
    }

    /// Checks access to mark tested
    func canTest() -> EventLoopFuture<(Project, GrantType)> {
        self
            .guard({ $0.1.canTest }, else: Abort(.forbidden, reason: "No Permisions To Mark Tested"))
            .map { $0 }
    }

    /// Checks any access
    func canView() -> EventLoopFuture<(Project, GrantType)> {
        self
            .map { $0 }
    }
}

struct GetProjectParams: Content {
    let project: String
}

struct PutProjectParams: Content {
    let project: String
    let title: String?
    let bundleId: String?
    let description: String?
    let telegramToken: String?
    let telegramId: String?
    let myteamToken: String?
    let myteamUrl: String?
    let myteamId: String?

    private enum CodingKeys: String, CodingKey {
        case project
        case title
        case bundleId = "bundle_id"
        case description
        case telegramToken = "telegram_token"
        case telegramId = "telegram_id"
        case myteamToken = "myteam_token"
        case myteamUrl = "myteam_url"
        case myteamId = "myteam_id"
    }
}
