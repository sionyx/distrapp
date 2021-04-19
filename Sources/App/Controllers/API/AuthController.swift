//
//  AuthController.swift
//  
//
//  Created by Вадим Балашов on 18.12.2020.
//

import Fluent
import Vapor

struct AuthController {
    private struct GetCodeParams: Content {
        let email: String
    }

    private struct GetTokenParams: Content {
        let email: String
        let code: String
        let place: String
    }

    // http://localhost:8080/auth/getcode?email=balashov@corp.mail.ru
    func getCode(req: Request) throws -> EventLoopFuture<Response> {
        guard let params = try? req.query.decode(GetCodeParams.self) else {
            throw Abort(.badRequest)
        }

        let code = (0..<6).map { _ in Int.random(in: 0...9) }.reduce("") { $0 + String($1) }

        return req.myTeam.sendMessage("Your one time code is \(code)", to: params.email)
            .flatMap {
                OneTimeCode.query(on: req.db)
                    .filter(\.$email == params.email)
                    .first()
                    .flatMap { oneTimeCode -> EventLoopFuture<Void> in
                        let saveResult = (oneTimeCode?.withValue(code) ?? OneTimeCode(value: code, email: params.email))
                            .save(on: req.db)

                        saveResult
                            .whenFailure({ error in
                                req.logger.report(error: error)
                            })

                        return saveResult
                    }
            }
            .transform(to: Response(status: .ok))
    }

    // http://localhost:8080/auth/gettoken?email=balashov@corp.mail.ru&code=913889
    func getToken(req: Request) throws -> EventLoopFuture<UserToken.Short> {
        guard let params = try? req.query.decode(GetTokenParams.self) else {
            throw Abort(.badRequest)
        }

        return OneTimeCode.query(on: req.db)
            .group(.and) { group in
                group
                    .filter(\.$email == params.email)
                    .filter(\.$value == params.code)
            }
            .first()
            .unwrap(or: Abort(.badRequest, reason: "Code not found. Use getcode before."))
            .flatMap { oneTimeCode -> EventLoopFuture<Void> in
                let created = oneTimeCode.created
                return oneTimeCode
                    .delete(force: true, on: req.db)
                    .flatMapThrowing {
                        guard let created = created,
                              created.addingTimeInterval(300) > Date() else {
                            throw Abort(.badRequest)
                        }
                    }
            }
            .flatMap { _ -> EventLoopFuture<User> in
                User.query(on: req.db)
                    .filter(\.$authId == params.email)
                    .first()
                    .unwrap(or: Abort(.notFound, reason: "User not found. Find @distrappbot bot in MyTeam and press start."))
            }
            .flatMap { user -> EventLoopFuture<UserToken.Short> in
                guard let userToken = try? user.generateToken(place: params.place) else {
                    return req.eventLoop.makeFailedFuture(Abort(.internalServerError, reason: "Token Cannot Be Generated"))
                }
                return userToken
                    .save(on: req.db)
                    .map { userToken.short }
            }
    }
}
