//
//  GrantsController.swift
//  
//
//  Created by Вадим Балашов on 23.08.2020.
//

import Fluent
import Vapor

struct GrantsController {

    // http://localhost:8080/grants
    func _index(req: Request) throws -> EventLoopFuture<[Grant.Short]> {
        return Grant.query(on: req.db)
            .with(\.$user)
            .with(\.$project)
            .all()
            .map { $0.map { $0.short }}
    }

    // http://localhost:8080/api/v1/grants?project=MINICLOUD
    func list(_ req: Request) throws -> EventLoopFuture<[Member]> {
        guard let currentUser = try? req.auth.require(User.self),
              let currentUserId = currentUser.id else {
            throw Abort(.unauthorized)
        }
        guard let params = try? req.query.decode(GetProjectParams.self) else {
            throw Abort(.badRequest)
        }

        let ownedProject = Project
            .by(name: params.project, on: req.db)
            .granted(to: currentUserId, on: req.db)
            .canInvite()

        let users = ownedProject
            .flatMap { project, _ -> EventLoopFuture<[Member]> in
                let r = Grant.query(on: req.db)
                    .filter(\.$project.$id == project.id!)
                    .with(\.$user)
                    .with(\.$project)
                    .all()
                    .map { $0.map { Member($0) }}

                return r
            }

        return users
    }

    // curl --header "Content-Type: application/json" --request POST --data '{"user": "mila.kirilenko@corp.mail.ru", "project": "MINICLOUD", "type": "upload"}' http://localhost:8080/api/v1/grants
    func add(_ req: Request) throws -> EventLoopFuture<HTTPStatus> {
        guard let currentUser = try? req.auth.require(User.self),
              let currentUserId = currentUser.id else {
            throw Abort(.unauthorized)
        }
        guard let shortGrant = try? req.query.decode(Grant.Short.self),
              let shortGrantType = shortGrant.type,
              shortGrantType != .owner else {
            throw Abort(.badRequest)
        }

        let ownedProject = Project
            .by(name: shortGrant.project, on: req.db)
            .granted(to: currentUserId, on: req.db)
            .canInvite()
            .map { $0.0 }

        let userToGrant = User
            .by(name: shortGrant.user, on: req.db)

        let savedGrant = ownedProject.and(userToGrant)
            .flatMap { project, user -> EventLoopFuture<Void> in
                guard let newGrant = try? Grant(project: project, user: user, type: shortGrantType) else {
                    return req.eventLoop.makeFailedFuture(Abort(.internalServerError, reason: "Grant Cannot Be Created"))
                }

                return newGrant
                    .save(on: req.db)
            }

        return savedGrant
            .transform(to: HTTPStatus.ok)
    }

    // curl --header "Content-Type: application/json" --request DELETE --data '{"user": "mila.kirilenko@corp.mail.ru", "project": "MINICLOUD"}' http://localhost:8080/api/v1/grants
    func delete(_ req: Request) throws -> EventLoopFuture<HTTPStatus> {
        guard let currentUser = try? req.auth.require(User.self),
              let currentUserId = currentUser.id else {
            throw Abort(.unauthorized)
        }
        guard let shortGrant = try? req.query.decode(Grant.Short.self) else {
            throw Abort(.badRequest)
        }

        let ownedProject = Project
            .by(name: shortGrant.project, on: req.db)
            .granted(to: currentUserId, on: req.db)
            .canInvite()
            .map { $0.0 }

        let grantedUser = User
            .by(name: shortGrant.user, on: req.db)

        let deletedGrant = ownedProject.and(grantedUser)
            .flatMap { project, user -> EventLoopFuture<Void> in
                Grant.query(on: req.db)
                    .group(.and) { group in
                        group
                            .filter(\.$user.$id == user.id!)
                            .filter(\.$project.$id == project.id!)
                    }
                    .first()
                    .unwrap(or: Abort(.notFound))
                    .flatMap { grant -> EventLoopFuture<Void> in
                        return grant.delete(force: true, on: req.db)
                    }
            }

        return deletedGrant
            .transform(to: HTTPStatus.ok)
    }
}