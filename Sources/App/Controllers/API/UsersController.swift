//
//  UsersController.swift
//  
//
//  Created by Вадим Балашов on 23.08.2020.
//

import Fluent
import Vapor

struct UsersController {
    // http://localhost:8080/users
    func _index(req: Request) throws -> EventLoopFuture<[User.Short]> {
        return User.query(on: req.db).all().mapEach { $0.short }
    }

    // http://localhost:8080/users/{id}
    func _one(req: Request) throws -> EventLoopFuture<User.Short> {
        guard let id = req.parameters.get("id"),
            let uuid = UUID(uuidString: id) else {
                throw Abort(.badRequest)
        }

        let responseResult = User.query(on: req.db)
            .filter(\.$id == uuid)
            .first()
            .unwrap(or: Abort(.notFound))
            .map { $0.short }

        //return req.eventLoop.makeSucceededFuture(user!)
        return responseResult
    }

    func me(req: Request) throws -> User.Short {
        return try req.auth.require(User.self).short
    }

    // curl --header "Content-Type: application/json" --request POST --data '{"first_name": "Vadim", "last_name": "Balashov", "auth_provider": "mailru", "auth_id": "balashov@corp.mail.ru"}' http://localhost:8080/users
    func add(_ req: Request) throws -> EventLoopFuture<HTTPStatus> {
        guard let userToSave = try? req.content.decode(User.self) else {
            throw Abort(.badRequest)
        }

        let saveResult = userToSave
            .save(on: req.db)
            .transform(to: HTTPStatus.ok)

        return saveResult
    }


    // curl -X DELETE http://localhost:8080/users/{id}
    func _delete(_ req: Request) throws -> EventLoopFuture<Response> {
        guard let id = req.parameters.get("id"),
            let uuid = UUID(uuidString: id) else {
                throw Abort(.badRequest)
        }

        return User.query(on: req.db)
            .filter(\.$id == uuid)
            .first()
            .unwrap(or: Abort(.notFound))
            .flatMapThrowing { user -> EventLoopFuture<Void> in
                return user.delete(on: req.db)
            }
            .transform(to: Response(status: .ok))
    }
}
