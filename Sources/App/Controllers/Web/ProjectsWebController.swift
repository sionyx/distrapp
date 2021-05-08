//
//  ProjectsWebController.swift
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

    func newProject(_ req: Request) throws -> EventLoopFuture<View> {
        guard let currentUser = try? req.auth.require(User.self) else {
            throw Abort(.unauthorized)
        }

        let projectName = req.session.data["projectName"]
        let projectTitle = req.session.data["projectTitle"]
        let projectBundle = req.session.data["projectBundle"]
        let projectDescription = req.session.data["projectDescription"]
        let invalidName = req.session.data["validName"] == "false"
        let invalidTitle = req.session.data["validTitle"] == "false"
        let invalidBundle = req.session.data["validBundle"] == "false"

        return req.view.render("projectnew", ProjectInfoContent(title: "New Project",
                                                                user: currentUser.short,
                                                                project: nil,
                                                                projectName: projectName,
                                                                projectTitle: projectTitle,
                                                                projectBundle: projectBundle,
                                                                projectDescription: projectDescription,
                                                                invalidName: invalidName,
                                                                invalidTitle: invalidTitle,
                                                                invalidBundle: invalidBundle))
    }

    func newProjectDone(_ req: Request) throws -> EventLoopFuture<Response> {
        guard let currentUser = try? req.auth.require(User.self) else {
            throw Abort(.unauthorized)
        }

        guard let shortProject = try? req.content.decode(Project.Short.self) else {
            throw Abort(.badRequest)
        }

        let projectName = shortProject.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let projectTitle = shortProject.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let projectBundle = shortProject.bundleId.trimmingCharacters(in: .whitespacesAndNewlines)
        let projectDescription = shortProject.description?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmptyValue

        let validName = projectName.count >= 4 && projectName.count <= 16
        let validTitle = !projectTitle.isEmpty
        let validBundle = !projectBundle.isEmpty

        req.session.data["projectName"] = projectName
        req.session.data["projectTitle"] = projectTitle
        req.session.data["projectBundle"] = projectBundle
        req.session.data["projectDescription"] = projectDescription
        req.session.data["validName"] = validName ? "true" : "false"
        req.session.data["validTitle"] = validTitle ? "true" : "false"
        req.session.data["validBundle"] = validBundle ? "true" : "false"

        guard validName,
              validTitle,
              validBundle else {
            return try newProject(req).encodeResponse(for: req)
        }

        let projectToSave = Project(name: projectName,
                                    title: projectTitle,
                                    bundleId: projectBundle,
                                    description: projectDescription,
                                    icon: nil)

        return req.db.transaction { database in
            return projectToSave
                .save(on: database)
                .flatMapThrowing { _ -> EventLoopFuture<Void> in
                    let grantToSave = try Grant(project: projectToSave, user: currentUser, type: .owner)

                    return grantToSave
                        .save(on: database)
                }
            }
            .transform(to: req.redirect(to: "/projects/\(shortProject.name)"))
    }

    func editProject(_ req: Request) throws -> EventLoopFuture<View> {
        guard let currentUser = try? req.auth.require(User.self),
              let currentUserId = currentUser.id else {
            throw Abort(.unauthorized)
        }

        guard let project = req.parameters.get("project") else {
            throw Abort(.badRequest)
        }

        return Project
            .by(name: project, on: req.db)
            .granted(to: currentUserId, on: req.db)
            .canEdit()
            .flatMap { project, _ in
                let projectTitle: String
                let projectBundle: String
                let projectDescription: String?
                let invalidTitle: Bool
                let invalidBundle: Bool

                if let name = req.session.data["editProjectName"],
                   name == project.name,
                   let title = req.session.data["editProjectTitle"],
                   let bundle = req.session.data["editProjectBundle"],
                   let description = req.session.data["editProjectDescription"] {
                    projectTitle = title
                    projectBundle = bundle
                    projectDescription = description
                    invalidTitle = req.session.data["editValidTitle"] == "false"
                    invalidBundle = req.session.data["editValidBundle"] == "false"
                }
                else {
                    projectTitle = project.title
                    projectBundle = project.bundleId
                    projectDescription = project.description
                    invalidTitle = false
                    invalidBundle = false
                }

                return req.view.render("projectedit", ProjectInfoContent(title: "Edit Project",
                                                                         user: currentUser.short,
                                                                         project: project,
                                                                         projectName: project.name,
                                                                         projectTitle: projectTitle,
                                                                         projectBundle: projectBundle,
                                                                         projectDescription: projectDescription,
                                                                         invalidName: false,
                                                                         invalidTitle: invalidTitle,
                                                                         invalidBundle: invalidBundle))
            }
    }

    func editProjectDone(_ req: Request) throws -> EventLoopFuture<Response> {
        guard let currentUser = try? req.auth.require(User.self),
              let currentUserId = currentUser.id else {
            throw Abort(.unauthorized)
        }

        guard let shortProject = try? req.content.decode(Project.Short.self) else {
            throw Abort(.badRequest)
        }

        let projectName = shortProject.name
        let projectTitle = shortProject.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let projectBundle = shortProject.bundleId.trimmingCharacters(in: .whitespacesAndNewlines)
        let projectDescription = shortProject.description?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmptyValue

        let validTitle = !projectTitle.isEmpty
        let validBundle = !projectBundle.isEmpty

        req.session.data["editProjectName"] = projectName
        req.session.data["editProjectTitle"] = projectTitle
        req.session.data["editProjectBundle"] = projectBundle
        req.session.data["editProjectDescription"] = projectDescription
        req.session.data["editValidTitle"] = validTitle ? "true" : "false"
        req.session.data["editValidBundle"] = validBundle ? "true" : "false"

        guard validTitle,
              validBundle else {
            return try editProject(req).encodeResponse(for: req)
        }

        return Project
            .by(name: projectName, on: req.db)
            .granted(to: currentUserId, on: req.db)
            .canEdit()
            .flatMap { project, _ -> EventLoopFuture<Void> in
                project.title = projectTitle
                project.bundleId = projectBundle
                project.description = projectDescription
                return project.save(on: req.db)
            }
            .transform(to: req.redirect(to: "/projects/\(projectName)"))
    }

    func iconProjectDone(_ req: Request) throws -> EventLoopFuture<Response> {
        guard let currentUser = try? req.auth.require(User.self),
              let currentUserId = currentUser.id else {
            throw Abort(.unauthorized)
        }

        guard let projectName = req.parameters.get("project") else {
            throw Abort(.badRequest)
        }

        guard let params = try? req.content.decode(UploadFileParams.self) else {
            throw Abort(.badRequest)
        }

        return Project
            .by(name: projectName, on: req.db)
            .granted(to: currentUserId, on: req.db)
            .canEdit()
            .flatMap { project, _ -> EventLoopFuture<(Project, String)> in
                let dirPath = URL(fileURLWithPath: "./Public/icons").path
                let filePath = URL(fileURLWithPath: "./Public/icons/\(project.name).png").path
                print("dir path: \(dirPath)")
                try? FileManager.default.createDirectory(atPath: dirPath, withIntermediateDirectories: true, attributes: nil)

                if FileManager.default.isDeletableFile(atPath: filePath) {
                    try? FileManager.default.removeItem(atPath: filePath)
                }

                return req.application.fileio.openFile(path: filePath,
                                                       mode: .write,
                                                       flags: .allowFileCreation(posixMode: 0x744),
                                                       eventLoop: req.eventLoop)
                    .flatMap { handle in
                        req.application.fileio.write(fileHandle: handle,
                                                     buffer: params.file.data,
                                                     eventLoop: req.eventLoop)
                            .flatMapThrowing { _ -> (Project, String) in
                                try handle.close()
                                return (project, filePath)
                            }
                    }
            }
            .flatMap { project, filePath -> EventLoopFuture<Void> in
                project.icon = "/icons/\(project.name).png"
                return project.save(on: req.db)
            }
            .transform(to: req.redirect(to: "/projects/\(projectName)"))
    }

    func deleteProject(_ req: Request) throws -> EventLoopFuture<View> {
        guard let currentUser = try? req.auth.require(User.self),
              let currentUserId = currentUser.id else {
            throw Abort(.unauthorized)
        }

        guard let projectName = req.parameters.get("project") else {
            throw Abort(.badRequest)
        }

        return Project
            .by(name: projectName, on: req.db)
            .granted(to: currentUserId, on: req.db)
            .canDelete()
            .flatMap { project, _ in
                return req.view.render("projectdelete", ProjectDeleteContent(user: currentUser.short,
                                                                             projectName: project.name))
            }
    }

    func deleteProjectDone(_ req: Request) throws -> EventLoopFuture<Response> {
        guard let currentUser = try? req.auth.require(User.self),
              let currentUserId = currentUser.id else {
            throw Abort(.unauthorized)
        }

        guard let projectName = req.parameters.get("project") else {
            throw Abort(.badRequest)
        }

        return Project
            .by(name: projectName, on: req.db)
            .granted(to: currentUserId, on: req.db)
            .canDelete()
            .flatMap { project, grants -> EventLoopFuture<(Project, Int)> in
                project.$branches.query(on: req.db)
                    .count()
                    .map { (project, $0) }
            }
            .guard({ $0.1 == 0 }, else: Abort(.preconditionFailed, reason: "Could not delete project with branches"))
            .flatMap { project, _ -> EventLoopFuture<Void> in
                project.delete(force: true, on: req.db)
            }
            .transform(to: req.redirect(to: "/projects"))
    }
}

struct ProjectsContent: WebSiteContent {
    var title = "Projects"
    let user: User.Short?
    let projects: [Project.Short]
}

struct ProjectInfoContent: WebSiteContent {
    var title: String
    let user: User.Short?
    let project: Project?
    let projectName: String?
    let projectTitle: String?
    let projectBundle: String?
    let projectDescription: String?
    let invalidName: Bool?
    let invalidTitle: Bool?
    let invalidBundle: Bool?
}

struct ProjectDeleteContent: WebSiteContent {
    var title = "Delete Project"
    let user: User.Short?
    let projectName: String
}

struct UploadFileParams: Content {
    let file: File
}
