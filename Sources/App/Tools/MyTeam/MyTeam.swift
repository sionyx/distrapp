//
//  MyTeam.swift
//  
//
//  Created by Вадим Балашов on 19.12.2020.
//

import Vapor
import Queues


class MyTeamConfiguration {
    static var host: String = "https://api.internal.myteam.mail.ru"
    static var token: String = ""
    static var pollTime: Int = 600
}

class MyTeam {
    private let client: Client

    fileprivate init(client: Client) {
        self.client = client
    }

    private struct MTResponse: Content {
        let ok: Bool
        let description: String?
    }

    func sendMessage(_ text: String, to email: String) -> EventLoopFuture<Void> {
        return client.post(URI(string: "\(MyTeamConfiguration.host)/bot/v1/messages/sendText")) { req in
            let message = ["token": MyTeamConfiguration.token,
                           "chatId": email,
                           "text": text]
            try req.content.encode(message, as: HTTPMediaType.formData)
        }.flatMapThrowing { res in
            guard let response = try? res.content.decode(MTResponse.self) else {
                throw Abort(.internalServerError)
            }

            guard response.ok else {
                throw Abort(.internalServerError, reason: response.description)
            }
        }
    }
}

extension Request {
    var myTeam: MyTeam {
        return MyTeam(client: self.client)
    }
}

extension QueueContext {
    var myTeam: MyTeam {
        return MyTeam(client: self.application.client)
    }
}
