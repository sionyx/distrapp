//
//  GrantsWebController.swift
//  
//
//  Created by Вадим Балашов on 08.05.2021.
//

import Foundation

import Vapor
import Leaf
import Fluent

struct GrantsWebController {

    func membersHandler(_ req: Request) throws -> EventLoopFuture<View> {
        guard let currentUser = try? req.auth.require(User.self),
              let currentUserId = currentUser.id else {
            throw Abort(.unauthorized)
        }

        guard let projectName = req.parameters.get("project") else {
            throw Abort(.badRequest)
        }

        return Project
            .by(name: projectName, on: req.db)
            .granted(to: currentUserId, on: req.db)
            .canInvite()
            .flatMap { project, _ -> EventLoopFuture<(Project, [Member])> in
                Grant.query(on: req.db)
                    .filter(\.$project.$id == project.id!)
                    .with(\.$user)
                    .with(\.$project)
                    .all()
                    .map { (project, $0.map { Member($0) }) }
            }
            .flatMap { project, members in
                let params = try? req.query.decode(MembersParams.self)

                return req.view.render("members", MembersContent(user: currentUser.short,
                                                                 project: project.short,
                                                                 members: members,
                                                                 inviteEmail: nil,
                                                                 invalidEmail: params?.notfound != nil))
            }
    }

    func inviteDone(_ req: Request) throws -> EventLoopFuture<Response> {
        guard let currentUser = try? req.auth.require(User.self),
              let currentUserId = currentUser.id else {
            throw Abort(.unauthorized)
        }

        guard let projectName = req.parameters.get("project"),
              let params = try? req.content.decode(InviteParams.self),
              params.grant != .owner else {
            throw Abort(.badRequest)
        }

        return Project
            .by(name: projectName, on: req.db)
            .granted(to: currentUserId, on: req.db)
            .canInvite()
            .flatMap { project, _ -> EventLoopFuture<(Project, User)> in
                User.query(on: req.db)
                    .filter(\.$authId == params.email)
                    .first()
                    .unwrap(or: Abort.redirect(to: "/projects/\(projectName)/members?notfound=1"))
                    .map { (project, $0) }
            }
            .flatMapThrowing { project, user -> EventLoopFuture<Void> in
                try Grant(project: project, user: user, type: params.grant)
                    .save(on: req.db)
            }
            .transform(to: req.redirect(to: "/projects/\(projectName)/members"))
    }

    func removeDone(_ req: Request) throws -> EventLoopFuture<Response> {
        guard let currentUser = try? req.auth.require(User.self),
              let currentUserId = currentUser.id else {
            throw Abort(.unauthorized)
        }

        guard let projectName = req.parameters.get("project"),
              let params = try? req.content.decode(RemoveParams.self) else {
            throw Abort(.badRequest)
        }

        return Project
            .by(name: projectName, on: req.db)
            .granted(to: currentUserId, on: req.db)
            .canInvite()
            .flatMap { project, _ -> EventLoopFuture<(Project, User)> in
                User.query(on: req.db)
                    .filter(\.$authId == params.email)
                    .first()
                    .unwrap(or: Abort.redirect(to: "/projects/\(projectName)/members"))
                    .map { (project, $0) }
            }
            .flatMap { project, user -> EventLoopFuture<Void> in
                Grant.query(on: req.db)
                    .group(.and) { group in
                        group
                            .filter(\.$user.$id == user.id!)
                            .filter(\.$project.$id == project.id!)
                    }
                    .first()
                    .unwrap(or: Abort(.notFound))
                    .guard( { $0.type != .owner }, else: Abort.redirect(to: "/projects/\(projectName)/members"))
                    .flatMap { grant -> EventLoopFuture<Void> in
                        return grant.delete(force: true, on: req.db)
                    }
            }
            .transform(to: req.redirect(to: "/projects/\(projectName)/members"))
    }
}

struct MembersContent: WebSiteContent {
    var title = "Members"
    let user: User.Short?
    let project: Project.Short
    let members: [Member]
    let inviteEmail: String?
    let invalidEmail: Bool?
}

struct InviteParams: Decodable {
    let email: String
    let grant: GrantType
}

struct RemoveParams: Decodable {
    let email: String
}

struct MembersParams: Content {
    let notfound: String?
}
