//
//  MyTeamJob.swift
//  
//
//  Created by Вадим Балашов on 24.12.2020.
//

import Vapor
import Fluent
import Queues

extension QueueName {
    static let myteam = QueueName(string: "myteam")
}

extension MyTeam {
    struct MyTeamJob: Job {
        typealias Payload = String

        static var lastEventId = 0

        func dequeue(_ context: QueueContext, _ payload: String) -> EventLoopFuture<Void> {
            return context.application.client.post(URI(string: "\(MyTeamConfiguration.host)/bot/v1/events/get")) { req in
                let message = ["token": MyTeamConfiguration.token,
                               "lastEventId": String(MyTeamJob.lastEventId),
                               "pollTime": String(MyTeamConfiguration.pollTime)]
                try req.content.encode(message, as: HTTPMediaType.formData)
            }.flatMap { res -> EventLoopFuture<Void> in
                guard let response = try? res.content.decode(MyTeam.EventsResponse.self) else {
                    return context.eventLoop.makeSucceededFuture(())
                }

                guard response.ok,
                      let events = response.events?.unpack() else {
                    return context.eventLoop.makeSucceededFuture(())
                }

                let messages = events.compactMap { event -> MyTeam.MessagePayload? in
                    guard event.type == .newMessage else {
                        return nil
                    }

                    return event.payload
                }

                let jobs = messages.compactMap { message -> EventLoopFuture<Void>? in
                    guard let text = message.text else {
                        return nil
                    }
                    switch text {
                    case "/start":
                        return context.queue.dispatch(MyTeam.StartHandler.self, message)
                    case "/ping":
                        return context.queue.dispatch(MyTeam.PingHandler.self, message)
                    default:
                        return nil
                    }
                }

                if let id = events.last?.eventId {
                    MyTeamJob.lastEventId = id
                }

                return context.eventLoop.flatten(jobs)
            }
            .flatMap {
                context.queue.dispatch(MyTeam.MyTeamJob.self, "")
            }
        }
    }
}
