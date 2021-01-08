//
//  MyTeam.swift
//  
//
//  Created by Вадим Балашов on 19.12.2020.
//

import Vapor
import Queues



enum MyTeam {
    class Configuration {
        static var host: String = "https://api.internal.myteam.mail.ru"
        static var token: String = ""
        static var pollTime: Int = 600
    }

    class Sender {
        private let client: Client

        fileprivate init(client: Client) {
            self.client = client
        }

        func sendMessage(_ text: String, to email: String) -> EventLoopFuture<Void> {
            return client.post(URI(string: "\(MyTeam.Configuration.host)/bot/v1/messages/sendText")) { req in
                let message = ["token": MyTeam.Configuration.token,
                               "chatId": email,
                               "text": text]
                try req.content.encode(message, as: HTTPMediaType.formData)
            }.flatMapThrowing { res in
                guard let response = try? res.content.decode(MyTeam.EventsResponse.self) else {
                    throw Abort(.internalServerError)
                }

                guard response.ok else {
                    throw Abort(.internalServerError, reason: response.description)
                }
            }
        }
    }

    class Listner {
        private weak var app: Application!
        private var handlers: [MyTeamHandler]!

        fileprivate init(app: Application) {
            self.app = app
        }

        var lastEventId = 0

        func configure(with handlers: [MyTeamHandler]) {
            let bot = MyTeam.Sender(client: app.client)
            self.handlers = handlers
            self.handlers.forEach { $0.configure(bot: bot) }
        }

        func listen() {
            let eventLoop = app.eventLoopGroup.next()
            
            _ = app.threadPool.runIfActive(eventLoop: eventLoop) { [weak app] () -> EventLoopFuture<Void> in
                while true {
                    guard let app = app else {
                        break
                    }
                    do {
                        app.logger.info("MyTeam start request")

                        try app.client.post(URI(string: "\(MyTeam.Configuration.host)/bot/v1/events/get")) { [weak self] req in
                            guard let self = self else {
                                return
                            }
                            let message = ["token": MyTeam.Configuration.token,
                                           "lastEventId": String(self.lastEventId),
                                           "pollTime": String(MyTeam.Configuration.pollTime)]
                            try req.content.encode(message, as: HTTPMediaType.formData)
                        }.flatMap { [weak self] res -> EventLoopFuture<Void> in
                            guard let self = self,
                                  let response = try? res.content.decode(MyTeam.EventsResponse.self) else {
                                return eventLoop.makeSucceededFuture(())
                            }

                            guard response.ok,
                                  let events = response.events?.unpack() else {
                                return eventLoop.makeSucceededFuture(())
                            }

                            let messages = events.compactMap { event -> MyTeam.MessagePayload? in
                                guard event.type == .newMessage else {
                                    return nil
                                }

                                return event.payload
                            }

                            let handles = messages.compactMap { message -> EventLoopFuture<Void>? in
                                guard let handler = self.handlers.first(where: {$0.canHandle(message) }) else {
                                    return nil
                                }

                                return handler.handle(message, eventLoop: eventLoop, db: app.db)
                            }

                            if let id = events.last?.eventId {
                                self.lastEventId = id
                            }

                            return eventLoop.flatten(handles)
                        }
                        .wait()
                    }
                    catch {
                        app.logger.report(error: error)
                    }
                }
                return eventLoop.makeSucceededFuture(())
            }
        }
    }
}

extension Request {
    var myTeam: MyTeam.Sender {
        return MyTeam.Sender(client: self.client)
    }
}

extension QueueContext {
    var myTeam: MyTeam.Sender {
        return MyTeam.Sender(client: self.application.client)
    }
}

extension Application {
    var myTeamListener: MyTeam.Listner {
        return MyTeam.Listner(app: self)
    }
}
