//
//  BranchesWebController.swift
//  
//
//  Created by Вадим Балашов on 18.04.2021.
//

import Vapor
import Leaf
import Fluent

struct BranchesWebController {
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
            .flatMap { project, grants -> EventLoopFuture<(Project.Short, GrantType, [Branch.Short])> in
                return project.$branches.query(on: req.db)
                    .all()
                    .map { (project.short, grants, $0.map { $0.short }) }
            }
            .flatMap { project, grants, branches in
                req.view.render("branches", BranchesContent(user: currentUser.short,
                                                            project: project,
                                                            branches: branches,
                                                            canInvite: grants.canInvite,
                                                            canEdit: grants.canEdit,
                                                            canDelete: grants.canDelete,
                                                            canUpload: grants.canUpload))
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
                req.view.render("upload", BranchUploadContent(user: currentUser.short,
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
            .flatMap { project, _, branch -> EventLoopFuture<(Project, String, Branch?)> in
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

struct BranchesContent: WebSiteContent {
    var title = "Branches"
    let user: User.Short?
    let project: Project.Short
    let branches: [Branch.Short]
    let canInvite: Bool?
    let canEdit: Bool?
    let canDelete: Bool?
    let canUpload: Bool?
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

struct BranchUploadContent: WebSiteContent {
    var title = "Upload"
    let user: User.Short?
    let project: Project.Short
    let branch: String?
}

struct UploadPostParams: Content {
    let branch: String
    let description: String
    let file: File
}
