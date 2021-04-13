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

    func loginHandler(_ req: Request) throws -> EventLoopFuture<View> {
        let user = try? req.auth.require(User.self)
        if user != nil {
            throw Abort.redirect(to: "/profile")
        }

        let params = try? req.query.decode(LoginParams.self)
        return req.view.render("login", LoginContent(user: user?.short, email: params?.email))
    }

    func loginDoneHandler(_ req: Request) throws -> Response {
        guard let user = try? req.auth.require(User.self) else {
            throw Abort.redirect(to: "/login?invalid=1")
        }

        if user.password == "" {
            return req.redirect(to: "/changepassword")
        }

        return req.redirect(to: "/projects")
    }

    func signupHandler(_ req: Request) throws -> EventLoopFuture<View> {
        let user = try? req.auth.require(User.self)
        if user != nil {
            throw Abort.redirect(to: "/profile")
        }

        return req.view.render("signup", SignupContent(user: user?.short))
    }

    func signupDoneHandler(_ req: Request) throws -> EventLoopFuture<Response> {
        guard let params = try? req.content.decode(SignupParams.self) else {
            throw Abort.redirect(to: "/signup?empty=1")
        }

        guard params.email.isValidEmail,
              params.password.isValidPassword,
              params.firstName.count >= 2,
              params.lastName.count >= 2,
              let digest = try? Bcrypt.hash(params.password) else {
            throw Abort.redirect(to: "/signup?invalid=1")
        }

        return User.query(on: req.db)
            .filter(\.$authId == params.email)
            .first()
            .flatMap { user in
                if user != nil {
                    return req.eventLoop.makeSucceededFuture(req.redirect(to: "/login?email=\(params.email)"))
                }
                let user = User(firstName: params.firstName,
                                lastName: params.lastName,
                                authProvider: "site",
                                authId: params.email,
                                password: digest)
                let save = user.create(on: req.db)

                save.whenComplete({ _ in
                    req.auth.login(user)
                })

                return save.transform(to: req.redirect(to: "/profile"))
            }
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
        guard let user = try? req.auth.require(User.self),
              let params = try? req.content.decode(NewPassParams.self) else {
            throw Abort(.badRequest)
        }

        guard params.password == params.password2,
              params.password.isValidPassword,
              let digest = try? Bcrypt.hash(params.password) else {
            throw Abort.redirect(to: "/changepassword")
        }

        user.password = digest
        return user.save(on: req.db)
            .transform(to: req.redirect(to: "/profile"))
    }

    func logoutHandler(_ req: Request) throws -> Response {
        req.auth.logout(User.self)
        return req.redirect(to: "/")
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

                return req.view.render("branch", BranchContent(og: OpenGraph(title: branch.tag,
                                                                             description: branch.description,
                                                                             image: project.icon),
                                                               user: currentUser?.short,
                                                               project: project.short,
                                                               branch: branch.short,
                                                               canProtect: grant?.canProtect,
                                                               canTest: grant?.canTest,
                                                               canUpload: grant?.canUpload,
                                                               installUrl: installUrl))
            }
    }

    func uploadHandler(_ req: Request) throws -> EventLoopFuture<View> {
        guard let currentUser = try? req.auth.require(User.self),
              let currentUserId = currentUser.id,
              let project = req.parameters.get("project") else {
            throw Abort(.unauthorized)
        }

        let branch = req.parameters.get("branch")

        return Project
            .by(name: project, on: req.db)
            .granted(to: currentUserId, on: req.db)
            .guard({ $1.canUpload }, else: Abort.redirect(to: "/projects/\(project)"))
            .flatMap { project, grant in
                req.view.render("upload", BracnchUploadContent(user: currentUser.short,
                                                               project: project.short,
                                                               branch: branch))
            }
    }

    func uploadDoneHandler(_ req: Request) throws -> EventLoopFuture<Response> {
        guard let currentUser = try? req.auth.require(User.self),
              let currentUserId = currentUser.id else {
            throw Abort(.unauthorized)
        }

        guard let project = req.parameters.get("project"),
              let params = try? req.content.decode(UploadPostParams.self) else {
            throw Abort(.badRequest)
        }

        return Project
            .by(name: project, on: req.db)
            .granted(to: currentUserId, on: req.db)
            .canUpload()
            .branchOrNot(by: params.branch, on: req.db)
            .flatMap { project, branch -> EventLoopFuture<(Project, String, Branch?)> in
                let dirPath = URL(fileURLWithPath: "./builds/\(project.name)/\(params.branch)")
                print("dir path: \(dirPath.absoluteString)")
                try? FileManager.default.createDirectory(atPath: dirPath.path, withIntermediateDirectories: true, attributes: nil)

                if let branch = branch {
                    let oldFilePath = URL(fileURLWithPath: "./builds/\(project.name)/\(params.branch)/\(branch.filename)").path
                    if FileManager.default.isDeletableFile(atPath: oldFilePath) {
                        try? FileManager.default.removeItem(atPath: oldFilePath)
                    }
                }

                let filePath = URL(fileURLWithPath: "./builds/\(project.name)/\(params.branch)/\(params.file.filename)").path
                return req.application.fileio.openFile(path: filePath,
                                                       mode: .write,
                                                       flags: .allowFileCreation(posixMode: 0x744),
                                                       eventLoop: req.eventLoop)
                    .flatMap { handle in
                        req.application.fileio.write(fileHandle: handle,
                                                     buffer: params.file.data,
                                                     eventLoop: req.eventLoop)
                            .flatMapThrowing { _ -> (Project, String, Branch?) in
                                try handle.close()
                                return (project, filePath, branch)
                            }
                    }
            }
            .flatMap { project, filePath, brunch -> EventLoopFuture<Void> in
                let attr = try? FileManager.default.attributesOfItem(atPath: filePath)
                let fileSize = Int(attr?[FileAttributeKey.size] as? UInt64 ?? 0)

                guard let brunchToSave = brunch ?? (try? Branch(project: project, tag: params.branch, filename: params.file.filename, size: 0, isTested: false, isProtected: false, description: params.description, buildNumber: 0)) else {
                    return req.eventLoop.makeFailedFuture(Abort(.internalServerError, reason: "Cannot create branch"))
                }
                brunchToSave.filename = params.file.filename
                brunchToSave.description = params.description.nonEmptyValue
                brunchToSave.size = fileSize
                brunchToSave.isTested = false
                brunchToSave.buildNumber += 1

                return brunchToSave.save(on: req.db)
            }
            .transform(to: req.redirect(to: "/projects/\(project)/\(params.branch)"))
    }
}

struct LoginParams: Content {
    let email: String?
}

struct WebAuthParams: Content {
    let email: String
    let token: String
}

struct NewPassParams: Content {
    let password: String
    let password2: String
}

struct SignupParams: Content {
    let firstName: String
    let lastName: String
    let email: String
    let password: String
}

struct UploadPostParams: Content {
    let branch: String
    let description: String
    let file: File
}

struct OpenGraph: Content {
    let title: String
    let description: String?
    let image: String?
}

protocol WebSiteContent: Content {
    var title: String { get }
    var og: OpenGraph? { get }
    var user: User.Short? { get }
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

struct LoginContent: WebSiteContent {
    var title = "Login"
    let user: User.Short?
    let email: String?
}

struct SignupContent: WebSiteContent {
    var title = "Sign Up"
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
    let og: OpenGraph?
    let user: User.Short?
    let project: Project.Short
    let branch: Branch.Short
    let canProtect: Bool?
    let canTest: Bool?
    let canUpload: Bool?
    let installUrl: String?
}

struct BracnchUploadContent: WebSiteContent {
    var title = "Upload"
    let user: User.Short?
    let project: Project.Short
    let branch: String?
}

struct ProfileContent: WebSiteContent {
    var title = "Profile"
    let user: User.Short?
}

struct ChangePasswordContent: WebSiteContent {
    var title = "Change Password"
    let user: User.Short?
}
