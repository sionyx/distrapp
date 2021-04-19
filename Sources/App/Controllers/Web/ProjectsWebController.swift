//
//  File.swift
//  
//
//  Created by Вадим Балашов on 18.04.2021.
//

import Vapor
import Leaf
import Fluent

struct ProjectsWebController {

    func projectsHandler(_ req: Request) throws -> EventLoopFuture<View> {
        guard let currentUser = try? req.auth.require(User.self) else {
            throw Abort(.unauthorized)
        }

        return Grant.query(on: req.db)
            .filter(\.$user.$id == currentUser.id!)
            .with(\.$project)
            .all()
            .map { $0.map { $0.project.short(with: $0.type) } }
            .flatMap { projects in
                req.view.render("projects", ProjectsContent(user: currentUser.short,
                                                            projects: projects))
            }
    }
}

struct ProjectsContent: WebSiteContent {
    var title = "Projects"
    let user: User.Short?
    let projects: [Project.Short]
}
