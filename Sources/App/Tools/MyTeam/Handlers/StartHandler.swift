//
//  StartHandler.swift
//  
//
//  Created by Вадим Балашов on 27.12.2020.
//

import Vapor
import Fluent
import Queues

extension MyTeam {
    struct StartHandler: Job {
        typealias Payload = MyTeam.MessagePayload
        func dequeue(_ context: QueueContext, _ payload: Payload) -> EventLoopFuture<Void> {
            let mtUser = payload.from
            return User.query(on: context.application.db)
                .filter(\.$authId == mtUser.userId)
                .first()
                .flatMap { user -> EventLoopFuture<Void> in
                    let userToSave = user ?? User(firstName: mtUser.firstName, lastName: mtUser.lastName, authProvider: "myteam", authId: mtUser.userId)
                    userToSave.authProvider = "myteam"
                    userToSave.firstName = mtUser.firstName
                    userToSave.lastName = mtUser.lastName
                    return userToSave.save(on: context.application.db)
                }
        }
    }
}
