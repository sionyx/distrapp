//
//  PingHandler.swift
//  
//
//  Created by Вадим Балашов on 27.12.2020.
//

import Vapor
import Fluent

extension MyTeam {
    class PingHandler: MyTeamHandler {
        private var bot: MyTeam.Sender!

        func configure(bot: MyTeam.Sender) {
            self.bot = bot
        }

        func canHandle(_ messagePayload: MyTeam.MessagePayload) -> Bool {
            messagePayload.text == "/ping"
        }

        func handle(_ messagePayload: MyTeam.MessagePayload, eventLoop: EventLoop, db: Database) -> EventLoopFuture<Void> {
            return bot.sendMessage("pong", to: messagePayload.from.userId)
        }
    }
}
