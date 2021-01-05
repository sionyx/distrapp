//
//  File.swift
//  
//
//  Created by Вадим Балашов on 24.12.2020.
//

import Vapor

extension MyTeam {
    struct EventsResponse: Content {
        let ok: Bool
        let description: String?
        let events: [FailableDecodable<MessageEvent>]?
    }

    struct MessageEvent: Codable {
        enum EventType: String, Codable {
            case newMessage
        }

        let eventId: Int
        let type: EventType
        let payload: MessagePayload
    }

    struct Chat: Codable {
        enum ChatType: String, Codable {
            case `private`
            case group
        }
        let chatId: String
        let type: ChatType
        let title: String?
    }

    struct MessageAuthor: Codable {
        let firstName: String
        let lastName: String
        let userId: String
    }

    struct MessagePayload: Codable {
        let chat: Chat
        let from: MessageAuthor
        let parts: [MessagePart]?
        let msgId: String
        let text: String?
        let timestamp: Int
    }

    struct MessagePart: Codable {
        enum PartType: String, Codable {
            case sticker
            case file
            case voice
        }

        struct Payload: Codable {
            enum PayloadType: String, Codable {
                case image
            }
            let fileId: String
            let caption: String?
            let type: PayloadType?
        }
        let type: PartType
        let payload: Payload
    }

}

extension MyTeam {
    struct FailableDecodable<Base: Codable>: Codable {
        let base: Base?

        init(_ base: Base) {
            self.base = base
        }

        init?(_ base: Base?) {
            guard let base = base else {
                return nil
            }
            self.base = base
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            self.base     = try? container.decode(Base.self)
        }
    }
}

extension Array {
    func unpack<T>() -> [T] where Element == MyTeam.FailableDecodable<T> {
        return self.compactMap { $0.base }
    }
}
