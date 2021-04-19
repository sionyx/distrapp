//
//  WebsiteController.swift
//  
//
//  Created by Вадим Балашов on 21.03.2021.
//

import Vapor
import Leaf
import Fluent

struct WebsiteController {
    func indexHandler(_ req: Request) throws -> EventLoopFuture<View> {
        let user = try? req.auth.require(User.self)

        return User.query(on: req.db)
            .count()
            .flatMap { users in
                Project.query(on: req.db)
                    .count()
                    .map { (users, $0) }
            }
            .flatMap { users, projects in
                Branch.query(on: req.db)
                    .count()
                    .map { (users, projects, $0) }
            }
            .flatMap { users, projects, branches in
                return req.view.render("index", IndexContent(user: user?.short,
                                                             users: users,
                                                             projects: projects,
                                                             branches: branches))
            }
    }
}


protocol WebSiteContent: Content {
    var title: String { get }
    var og: OpenGraph? { get }
    var user: User.Short? { get }
}

struct OpenGraph: Content {
    let title: String
    let description: String?
    let image: String?
}

extension WebSiteContent {
    var og: OpenGraph? {
        return nil
    }
}

struct IndexContent: WebSiteContent {
    var title = "Home"
    let user: User.Short?
    let users: Int
    let projects: Int
    let branches: Int
}
