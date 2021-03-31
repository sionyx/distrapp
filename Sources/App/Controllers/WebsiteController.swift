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
        return req.view.render("index", IndexContent(user: user?.short))
    }

    func loginHandler(_ req: Request) throws -> EventLoopFuture<View> {
        let user = try? req.auth.require(User.self)
        return req.view.render("login", LoginContent(user: user?.short))
    }

    func loginDoneHandler(_ req: Request) throws -> Response {
        guard let user = try? req.auth.require(User.self) else {
            return req.redirect(to: "/login?invalid=1")
        }

        if user.password == "" {
            return req.redirect(to: "/changepassword")
        }

        return req.redirect(to: "/projects")
    }

    func authDoneHandler(_ req: Request) throws -> EventLoopFuture<Response> {
        guard let authParams = try? req.content.decode(WebAuthParams.self) else {
            throw Abort(.badRequest)
        }

        let a = UserToken.query(on: req.db)
            .filter(\.$value == authParams.token)
            .with(\.$user)
            .first()
            .map { token -> Response in
                guard let token = token,
                      token.user.authId == authParams.email else {
                    return req.redirect(to: "/login?invalid=1")
                }
                req.auth.login(token.user)
                return req.redirect(to: "/projects")
            }

        return a
    }

    func profileHandler(_ req: Request) throws -> EventLoopFuture<View> {
        guard let user = try? req.auth.require(User.self) else {
            throw Abort(.unauthorized)
        }

        return req.view.render("profile", ProfileContent(user: user.short))
    }

    func changePasswordHandler(_ req: Request) throws -> EventLoopFuture<View> {
        guard let user = try? req.auth.require(User.self) else {
            throw Abort(.unauthorized)
        }

        return req.view.render("changepassword", ChangePasswordContent(user: user.short))
    }

    func changePasswordDoneHandler(_ req: Request) throws -> EventLoopFuture<Response> {
        enum PasswordError: Error {
            case invalidChar
        }
        let validchars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890-=!@#$%^&*()_+<>/\\;:'\"[]{}~`"
        guard let user = try? req.auth.require(User.self),
              let params = try? req.content.decode(NewPassParams.self) else {
            throw Abort(.badRequest)
        }

        guard params.password == params.password2,
              params.password.count > 8,
              params.password.reduce(true, { $0 && validchars.contains($1) } ),
              let digest = try? Bcrypt.hash(params.password) else {
            return req.eventLoop.makeSucceededFuture(req.redirect(to: "/changepassword"))
        }

        user.password = digest
        return user.save(on: req.db)
            .transform(to: req.redirect(to: "/profile"))
    }

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

    func branchesHandler(_ req: Request) throws -> EventLoopFuture<View> {
        guard let currentUser = try? req.auth.require(User.self),
              let currentUserId = currentUser.id,
              let project = req.parameters.get("project") else {
            throw Abort(.unauthorized)
        }

        return Project
            .by(name: project, on: req.db)
            .granted(to: currentUserId, on: req.db)
            .canView()
            .flatMap { project -> EventLoopFuture<(Project.Short, [Branch.Short])> in
                return project.$branches.query(on: req.db)
                    .all()
                    .map { (project.short, $0.map { $0.short }) }
            }
            .flatMap { project, branches in
                req.view.render("branches", BranchesContent(user: currentUser.short,
                                                            project: project,
                                                            branches: branches))
            }
    }

    func branchHandler(_ req: Request) throws -> EventLoopFuture<View> {
        guard let project = req.parameters.get("project"),
              let branch = req.parameters.get("branch"),
              let host = req.headers.first(name: "Host"),
              let ua = req.headers.first(name: "User-Agent") else {
            throw Abort(.unauthorized)
        }

        let currentUser = try? req.auth.require(User.self)
        let currentUserId = currentUser?.id

        return Project
            .by(name: project, on: req.db)
            .grantedOrNot(to: currentUserId, on: req.db)
            .branch(by: branch, on: req.db)
            .flatMap { project, grant, branch in
                var installUrl: String?
                if ua.contains("iPhone OS") {
                    installUrl = "itms-services://?action=download-manifest&url=https://\(host)/install/\(project.name)/\(branch.tag)/manifest.plist"
                }

                return req.view.render("branch", BranchContent(user: currentUser?.short,
                                                               project: project.short,
                                                               branch: branch.short,
                                                               canProtect: grant?.canProtect,
                                                               canTest: grant?.canTest,
                                                               canUpload: grant?.canUpload,
                                                               installUrl: installUrl))
            }
    }


}

struct WebAuthParams: Content {
    let email: String
    let token: String
}

struct NewPassParams: Content {
    let password: String
    let password2: String
}

protocol WebSiteContent: Content {
    var title: String { get }
    var user: User.Short? { get }
}

struct IndexContent: WebSiteContent {
    var title = "Home"
    let user: User.Short?
}

struct LoginContent: WebSiteContent {
    var title = "Login"
    let user: User.Short?
}

struct ProjectsContent: WebSiteContent {
    var title = "Projects"
    let user: User.Short?
    let projects: [Project.Short]
}

struct BranchesContent: WebSiteContent {
    var title = "Branches"
    let user: User.Short?
    let project: Project.Short
    let branches: [Branch.Short]
}

struct BranchContent: WebSiteContent {
    var title = "Branch"
    let user: User.Short?
    let project: Project.Short
    let branch: Branch.Short
    let canProtect: Bool?
    let canTest: Bool?
    let canUpload: Bool?
    let installUrl: String?
}

struct ProfileContent: WebSiteContent {
    var title = "Profile"
    let user: User.Short?
}

struct ChangePasswordContent: WebSiteContent {
    var title = "Change Password"
    let user: User.Short?
}
