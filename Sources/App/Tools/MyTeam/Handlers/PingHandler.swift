//
//  PingHandler.swift
//  
//
//  Created by Вадим Балашов on 27.12.2020.
//

import Vapor
import Fluent
import Queues

extension MyTeam {
    struct PingHandler: Job {
        typealias Payload = MyTeam.MessagePayload
        func dequeue(_ context: QueueContext, _ payload: Payload) -> EventLoopFuture<Void> {
            return context.myTeam.sendMessage("pong", to: payload.from.userId)
        }
    }
}
