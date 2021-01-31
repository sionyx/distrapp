import Fluent
import Vapor

struct BranchController {
    // http://localhost:8080/branches
    func _index(req: Request) throws -> EventLoopFuture<[Branch.Short]> {
        return Branch.query(on: req.db).all().map { $0.map { $0.short }}
    }

    func list(req: Request) throws -> EventLoopFuture<[Branch.Short]> {
        guard let currentUser = try? req.auth.require(User.self),
              let currentUserId = currentUser.id else {
            throw Abort(.unauthorized)
        }
        guard let params = try? req.query.decode(GetProjectParams.self) else {
            throw Abort(.badRequest)
        }

        let allowedProject = Project
            .by(name: params.project, on: req.db)
            .granted(to: currentUserId, on: req.db)
            .canView()

        let branches = allowedProject
            .flatMap { project -> EventLoopFuture<[Branch.Short]> in
                return project.$branches.query(on: req.db)
                    .all()
                    .map { $0.map { $0.short }}
            }

        return branches
    }

    // curl -X PUT http://localhost:8080/api/v1/branches?project=MINICLOUD&branch=MINICLOUD-1234&is_protected=false&is_tested=true&description=1234567890
    func update(_ req: Request) throws -> EventLoopFuture<HTTPStatus> {
        guard let currentUser = try? req.auth.require(User.self),
              let currentUserId = currentUser.id else {
            throw Abort(.unauthorized)
        }
        guard let params = try? req.query.decode(PutBranchParams.self) else {
            throw Abort(.badRequest)
        }

        let allowedProject = Project
            .by(name: params.project, on: req.db)
            .granted(to: currentUserId, on: req.db)

        let branch = allowedProject
            .branch(by: params.branch, on: req.db)

        return branch
            .flatMapThrowing { _, grant, branch -> EventLoopFuture<Void> in
                if let isProtected = params.isProtected,
                   grant.canProtect {
                    branch.isProtected = isProtected
                }

                if let isTested = params.isTested,
                   grant.canTest {
                    branch.isTested = isTested
                }

                if let description = params.description ,
                   grant.canUpload {
                    branch.description = description
                }

                return branch.update(on: req.db)
            }
            .transform(to: .ok)
    }

    // curl -X DELETE http://localhost:8080/branch/PULSAR-1234
    func delete(_ req: Request) throws -> EventLoopFuture<HTTPStatus> {
        guard let currentUser = try? req.auth.require(User.self),
              let currentUserId = currentUser.id else {
            throw Abort(.unauthorized)
        }
        guard let params = try? req.query.decode(GetBranchParams.self) else {
            throw Abort(.badRequest)
        }

        let allowedProject = Project
            .by(name: params.project, on: req.db)
            .granted(to: currentUserId, on: req.db)
            .canView()

        let branch = allowedProject
            .branch(by: params.branch, on: req.db)

        return branch
            .flatMapThrowing { _, branch -> EventLoopFuture<Void> in
                let filePath = URL(fileURLWithPath: "./\(branch.tag)/\(branch.filename)")
                try FileManager.default.removeItem(at: filePath)

                let dirPath = URL(fileURLWithPath: "./\(branch.tag)")
                try FileManager.default.removeItem(at: dirPath)

                return branch.delete(on: req.db)
            }
            .transform(to: .ok)
    }


    //curl -X POST -v --header "Authorization: Bearer XXXX" --data-binary @Channel-Alpha.ipa "http://localhost:8080/api/v1/upload?project=MINICLOUD&branch=MINICLOUD-1234&description=4321&filename=Channel-Alpha.ipa"
    func upload(_ req: Request) throws -> EventLoopFuture<HTTPStatus> {
        guard let currentUser = try? req.auth.require(User.self),
              let currentUserId = currentUser.id else {
            throw Abort(.unauthorized)
        }

        guard let params = try? req.query.decode(PostBranchParams.self) else {
            throw Abort(.badRequest)
        }

        // create dir
        let dirPath = URL(fileURLWithPath: "./\(params.branch)")
        print("dir path: \(dirPath.absoluteString)")
        try FileManager.default.createDirectory(atPath: dirPath.path, withIntermediateDirectories: true, attributes: nil)

        let filePath = URL(fileURLWithPath: "./\(params.branch)/\(params.filename)").path
        guard FileManager.default.createFile(atPath: filePath, contents: nil, attributes: nil),
              let fileHandle = FileHandle(forWritingAtPath: filePath) else {
            throw Abort(.internalServerError)
        }

        let requestResult = req.eventLoop.makePromise(of: HTTPStatus.self)
        req.body.drain { drainResult in
            switch drainResult {
            case .buffer(let buffer):
                debugPrint(buffer)
                if let data = buffer.getData(at: 0, length: buffer.readableBytes) {
                    fileHandle.write(data)
                }
                return req.eventLoop.makeSucceededFuture(())
            case .error(let error):
                fileHandle.closeFile()
                requestResult.fail(error)
                return req.eventLoop.makeSucceededFuture(())
            case .end:
                fileHandle.closeFile()

                let allowedProject = Project
                    .by(name: params.project, on: req.db)
                    .granted(to: currentUserId, on: req.db)
                    .canUpload()


                print(drainResult)
                let attr = try? FileManager.default.attributesOfItem(atPath: filePath)
                let fileSize = Int(attr?[FileAttributeKey.size] as? UInt64 ?? 0)

                let queryResult = allowedProject
                    .flatMap { project -> EventLoopFuture<(Project, Branch?)> in
                        return project.$branches.query(on: req.db)
                            .filter(\.$tag == params.branch)
                            .first()
                            .map { (project, $0)  }
                    }
                    .flatMap { project, brunch -> EventLoopFuture<Void> in
                        guard let brunchToSave = brunch ?? (try? Branch(project: project, tag: params.branch, filename: params.filename, size: 0, isTested: false, isProtected: false, description: params.description, buildNumber: 0)) else {
                            return req.eventLoop.makeFailedFuture(Abort(.internalServerError, reason: "Cannot create branch"))
                        }
                        brunchToSave.filename = params.filename
                        brunchToSave.description = params.description
                        brunchToSave.size = fileSize
                        brunchToSave.isTested = false
                        brunchToSave.buildNumber += 1

                        let saveResult = brunchToSave.save(on: req.db)

                        saveResult.whenComplete { result in
                            switch result {
                            case .success:
                                requestResult.succeed(.ok)
                            case .failure:
                                requestResult.succeed(.internalServerError)
                            }
                        }

                        return saveResult
                    }

                return queryResult
            }
        }
        return requestResult.futureResult
    }
}
