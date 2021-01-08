//
//  File.swift
//  
//
//  Created by Вадим Балашов on 07.01.2021.
//

import Vapor
import Fluent

protocol MyTeamHandler {
    func configure(bot: MyTeam.Sender)
    func canHandle(_ messagePayload: MyTeam.MessagePayload) -> Bool
    func handle(_ messagePayload: MyTeam.MessagePayload, eventLoop: EventLoop, db: Database) -> EventLoopFuture<Void>
}
