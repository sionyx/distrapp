import Fluent
import Vapor

struct BranchController {
    // http://localhost:8080/branches
    func index(req: Request) throws -> EventLoopFuture<[Branch]> {
        return Branch.query(on: req.db).all()
    }

    // http://localhost:8080/branch/PULSAR-1234
    func one(req: Request) throws -> EventLoopFuture<Branch> {
        guard let tag = req.parameters.get("tag") else {
            throw Abort(.badRequest)
        }

        let responseResult = Branch.query(on: req.db)
            .filter(\.$tag == tag)
            .first()
            .unwrap(or: Abort(.notFound))

        return responseResult
    }

    // curl -X DELETE http://localhost:8080/branch/PULSAR-1234
    func delete(_ req: Request) throws -> EventLoopFuture<Response> {
        guard let tag = req.parameters.get("tag") else {
            throw Abort(.badRequest)
        }

        return Branch.query(on: req.db)
            .filter(\.$tag == tag)
            .first()
            .unwrap(or: Abort(.notFound))
            .flatMapThrowing { branch -> EventLoopFuture<Void> in
                let filePath = URL(fileURLWithPath: "./\(branch.tag)/\(branch.filename)")
                try FileManager.default.removeItem(at: filePath)

                let dirPath = URL(fileURLWithPath: "./\(branch.tag)")
                try FileManager.default.removeItem(at: dirPath)

                return branch.delete(on: req.db)
            }
            .transform(to: Response(status: .ok))
    }


    // http://localhost:8080/download/PULSAR-1234
    func download(_ req: Request) throws -> EventLoopFuture<Response> {
        guard let tag = req.parameters.get("tag") else {
            throw Abort(.badRequest)
        }

        let responseResult = Branch.query(on: req.db)
            .filter(\.$tag == tag)
            .first()
            .unwrap(or: Abort(.notFound))
            .flatMapThrowing { branch -> Response in
                let filePath = URL(fileURLWithPath: "./\(tag)/\(branch.filename)")

                guard let attributes = try? FileManager.default.attributesOfItem(atPath: filePath.path),
                    let fileSize = (attributes[.size] as? NSNumber)?.intValue else {
                        throw Abort(.internalServerError)
                }

                let response = Response(status: .ok)
                response.headers.contentDisposition = .init(.attachment, name: nil, filename: branch.filename)
                response.body = Response.Body(stream: { stream in
                    req.fileio.readFile(at: filePath.path) { chunk -> EventLoopFuture<Void> in
                            return stream.write(.buffer(chunk))
                        }
                        .whenComplete { result in
                            switch result {
                            case .failure(let error):
                                stream.write(.error(error), promise: nil)
                            case .success:
                                stream.write(.end, promise: nil)
                            }
                        }
                    }, count: fileSize)

                return response
            }

        return responseResult
    }


    // curl -X POST -v --data-binary @Channel-Alpha.ipa http://localhost:8080/upload/PULSAR-1234/Channel-Alpha.ipa
    func upload(_ req: Request) throws -> EventLoopFuture<HTTPStatus> {
        guard let tag = req.parameters.get("tag"),
            let filename = req.parameters.get("filename") else {
                throw Abort(.badRequest)
        }

        // create dir
        let dirPath = URL(fileURLWithPath: "./\(tag)")
        print("dir path: \(dirPath.absoluteString)")
        try FileManager.default.createDirectory(atPath: dirPath.path, withIntermediateDirectories: true, attributes: nil)

        let filePath = URL(fileURLWithPath: "./\(tag)/\(filename)")
        guard FileManager.default.createFile(atPath: filePath.path, contents: nil, attributes: nil),
            let fileHandle = FileHandle(forWritingAtPath: filePath.path) else {
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

                let queryResult = Branch.query(on: req.db)
                    .filter(\.$tag == tag)
                    .first()
                    .flatMap { brunch -> EventLoopFuture<Void> in
                        let brunchToSave = brunch ?? Branch(tag: tag, filename: filename, tested: false, description: "")

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

    // http://localhost:8080/install/PULSAR-1234
    func install(_ req: Request) throws -> EventLoopFuture<Response> {
        guard let tag = req.parameters.get("tag"),
            let host = req.headers.first(name: "Host") else {
                throw Abort(.badRequest)
        }

        return Branch.query(on: req.db)
            .filter(\.$tag == tag)
            .first()
            .unwrap(or: Abort(.notFound))
            .flatMap { brunch -> EventLoopFuture<Response> in
                // <a href="itms-services://?action=download-manifest&url=https://your.domain.com/your-app/manifest.plist">Awesome App</a>
                let response = req.redirect(to: "itms-services://?action=download-manifest&url=https://\(host)/install/\(brunch.tag)/manifest.plist", type: .temporary)
                return req.eventLoop.makeSucceededFuture(response)
            }
    }


    // http://localhost:8080/install/PULSAR-1234/manifest.plist
    func installManifest(_ req: Request) throws -> EventLoopFuture<Response> {
        guard let tag = req.parameters.get("tag"),
            let host = req.headers.first(name: "Host") else {
                throw Abort(.badRequest)
        }

        return Branch.query(on: req.db)
            .filter(\.$tag == tag)
            .first()
            .unwrap(or: Abort(.notFound))
            .flatMap { brunch -> EventLoopFuture<Response> in
                let manifestTemplate = R.manifest
                let manifest = manifestTemplate
                    .replacingOccurrences(of: "${DOMAIN}", with: host)
                    .replacingOccurrences(of: "${BRANCH_TAG}", with: tag)
                    .replacingOccurrences(of: "${FILE_NAME}", with: brunch.filename)
                    .replacingOccurrences(of: "${BUNDLE_IDENTIFIER}", with: "ru.mail.channel-alpha")
                    .replacingOccurrences(of: "${APPLICATION_VERSION}", with: "1.0")
                    .replacingOccurrences(of: "${DISPLAY_NAME}", with: "channel-alpha")

                let response = Response(status: .ok, body: Response.Body(string: manifest))
                return req.eventLoop.makeSucceededFuture(response)
            }
    }
}
