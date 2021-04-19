//
//  ProjectsController.swift
//  
//
//  Created by Вадим Балашов on 23.08.2020.
//

import Fluent
import Vapor

struct ProjectsController {
    // http://localhost:8080/projects
    func _index(req: Request) throws -> EventLoopFuture<[Project.Short]> {
        return Project.query(on: req.db).all().map { $0.map { $0.short }}

    }

    // http://localhost:8080/projects/{id}
    func _one(req: Request) throws -> EventLoopFuture<Project.Short> {
        guard let id = req.parameters.get("id"),
            let uuid = UUID(uuidString: id) else {
                throw Abort(.badRequest)
        }

        let responseResult = Project.query(on: req.db)
            .filter(\.$id == uuid)
            .first()
            .unwrap(or: Abort(.notFound))
            .map { $0.short }

        return responseResult
    }

    // http://localhost:8080/api/v1/projects
    func list(req: Request) throws -> EventLoopFuture<[Project.Short]> {
        guard let currentUser = try? req.auth.require(User.self) else {
            throw Abort(.unauthorized)
        }

        return Grant.query(on: req.db)
            .filter(\.$user.$id == currentUser.id!)
            .with(\.$project)
            .all()
            .map { $0.map { $0.project.short(with: $0.type) } }
    }


    // curl --header "Content-Type: application/json" --header "Authorization: Bearer XXXX" --request POST --data '{"name": "SMOTRI", "title": "Смотри Mail.ru"}' http://localhost:8080/projects
    func add(_ req: Request) throws -> EventLoopFuture<HTTPStatus> {
        guard let currentUser = try? req.auth.require(User.self) else {
            throw Abort(.unauthorized)
        }
        guard let shortProject = try? req.content.decode(Project.Short.self) else {
            throw Abort(.badRequest)
        }

        let projectToSave = shortProject.long

        return req.db.transaction { database in
            return projectToSave
                .save(on: database)
                .flatMapThrowing { _ -> EventLoopFuture<Void> in
                    let grantToSave = try Grant(project: projectToSave, user: currentUser, type: .owner)

                    return grantToSave
                        .save(on: database)
                }
            }
            .transform(to: HTTPStatus.ok)
    }


    // curl -X PUT http://localhost:8080/api/v1/projects?project=MINICLOUD
    func update(_ req: Request) throws -> EventLoopFuture<HTTPStatus> {
        guard let currentUser = try? req.auth.require(User.self),
              let currentUserId = currentUser.id else {
            throw Abort(.unauthorized)
        }
        guard let params = try? req.query.decode(PutProjectParams.self) else {
            throw Abort(.badRequest)
        }

        let project = Project
            .by(name: params.project, on: req.db)
            .granted(to: currentUserId, on: req.db)
            .canEdit()


        return project
            .flatMapThrowing {project -> EventLoopFuture<Void> in
                project.title = params.title?.nonEmptyValue ?? project.title
                project.bundleId = params.bundleId?.nonEmptyValue ?? project.bundleId
                project.description = params.description ?? project.description
                project.telegramToken = params.telegramToken ?? project.telegramToken
                project.telegramId = params.telegramId ?? project.telegramId
                project.myteamToken = params.myteamToken ?? project.myteamToken
                project.myteamUrl = params.myteamUrl ?? project.myteamUrl
                project.myteamId = params.myteamId ?? project.myteamId

                return project.update(on: req.db)
            }
            .transform(to: .ok)
    }


    // curl -X DELETE http://localhost:8080/api/v1/projects?project=MINICLOUD
    func delete(_ req: Request) throws -> EventLoopFuture<Response> {
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
            .canDelete()

        return ownedProject
            .flatMap { project -> EventLoopFuture<Void> in
                return req.db.transaction { database in
                    return Grant.query(on: database)
                        .filter(\Grant.$project.$id == project.id!)
                        .delete()
                        .flatMap {
                            project.delete(on: database)
                        }
                }
            }
            .transform(to: Response(status: .ok))
    }
}
