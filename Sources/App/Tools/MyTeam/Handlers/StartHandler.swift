//
//  StartHandler.swift
//  
//
//  Created by Вадим Балашов on 27.12.2020.
//

import Vapor
import Fluent

extension MyTeam {
    class StartHandler: MyTeamHandler {
        private var bot: MyTeam.Sender!

        func configure(bot: MyTeam.Sender) {
            self.bot = bot
        }

        func canHandle(_ messagePayload: MyTeam.MessagePayload) -> Bool {
            messagePayload.text == "/start"
        }

        func handle(_ messagePayload: MyTeam.MessagePayload, eventLoop: EventLoop, db: Database) -> EventLoopFuture<Void> {
            let mtUser = messagePayload.from
            return User.query(on: db)
                .filter(\.$authId == mtUser.userId)
                .first()
                .flatMap { [weak self] user -> EventLoopFuture<Void> in
                    guard let self = self else {
                        return eventLoop.makeSucceededFuture(())
                    }
                    let userToSave: User
                    let reply: EventLoopFuture<Void>
                    if let user = user {
                        userToSave = user
                        userToSave.authProvider = "myteam"
                        userToSave.firstName = mtUser.firstName
                        userToSave.lastName = mtUser.lastName
                        reply = self.bot.sendMessage("User Info Updated", to: mtUser.userId)
                    }
                    else {
                        userToSave = User(firstName: mtUser.firstName, lastName: mtUser.lastName, authProvider: "myteam", authId: mtUser.userId, password: "")
                        reply = self.bot.sendMessage("Welcome to distr.app! User Created", to: mtUser.userId)
                    }

                    let saveResult = userToSave.save(on: db)

                    return eventLoop.flatten([reply, saveResult])
                }
        }
    }
}
