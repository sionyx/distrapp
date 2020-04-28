import Fluent
import Vapor

struct BrunchController {
    // http://localhost:8080/branches
    func index(req: Request) throws -> EventLoopFuture<[Brunch]> {
        return Brunch.query(on: req.db).all()
    }

    // http://localhost:8080/branch/PULSAR-3456
//    func one(req: Request) throws -> EventLoopFuture<Brunch> {
//        return try req.parameters.next(Brunch.self).flatMap { brunch in
//            return brunch.save(on: req)
//        }
//        //return Brunch.query(on: req).all()
//    }

//    func create(req: Request) throws -> EventLoopFuture<Brunch> {
//        let brunch = try req.content.decode(Brunch.self)
//        return brunch.save(on: req.db).map { brunch }
//    }


    // http://localhost:8080/new?tag=PULSAR-3456&filename=app.ipa
//    func createNew(req: Request) throws -> EventLoopFuture<Brunch> {
////        let tagString = try req.query.get(String.self, at: "tag")
////        let filenameString = try req.query.get(String.self, at: "filename")
////
////
////        let brunch = Brunch(id: nil, tag: tagString, filename: filenameString)
////        return brunch.save(on: req)
//
//        let brunch = try req.query.get(Brunch.self)
//        return brunch.save(on: req)
//
//
////        return try req.parameters.next(Brunch.self).flatMap { brunch in
////            return brunch.save(on: req)
////        }
//
//    }

//    func delete(req: Request) throws -> EventLoopFuture<HTTPStatus> {
//        return Brunch.find(req.parameters.get("branchID"), on: req.db)
//            .unwrap(or: Abort(.notFound))
//            .flatMap { $0.delete(on: req.db) }
//            .transform(to: .ok)
//    }


    // http://localhost:8080/download/PULSAR-1234
    func download(_ req: Request) throws -> EventLoopFuture<Response> {
        guard let tag = req.parameters.get("tag") else {
            return req.eventLoop.makeSucceededFuture(Response(status: .badRequest))
        }

        let responseResult = Brunch.query(on: req.db)
            .filter(\.$tag == tag)
            .first()
            .flatMap { brunch -> EventLoopFuture<Response> in
                guard let filename = brunch?.filename else {
                        return req.eventLoop.makeSucceededFuture(Response(status: .notFound))
                }

                let filePath = URL(fileURLWithPath: "./\(tag)/\(filename)")

                guard let attributes = try? FileManager.default.attributesOfItem(atPath: filePath.path),
                    let fileSize = (attributes[.size] as? NSNumber)?.intValue else {
                        return req.eventLoop.makeSucceededFuture(Response(status: .notFound))
                }

                let response = Response(status: .ok)
                response.headers.contentDisposition = .init(.attachment, name: nil, filename: filename)
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

                return req.eventLoop.makeSucceededFuture(response)
            }

        return responseResult
    }


    // curl -X POST -v --data-binary @Channel-Alpha.ipa http://localhost:8080/upload/PULSAR-1234/Channel-Alpha.ipa
    func upload(_ req: Request) throws -> EventLoopFuture<HTTPStatus> {

        guard let tag = req.parameters.get("tag"),
            let filename = req.parameters.get("filename") else {
                return req.eventLoop.makeSucceededFuture(.badRequest)
        }

        // create dir
        let dirPath = URL(fileURLWithPath: "./\(tag)")
        print("dir path: \(dirPath.absoluteString)")
        try FileManager.default.createDirectory(atPath: dirPath.path, withIntermediateDirectories: true, attributes: nil)

        let filePath = URL(fileURLWithPath: "./\(tag)/\(filename)")
        FileManager.default.createFile(atPath: filePath.path, contents: nil, attributes: nil)
        guard let fileHandle = FileHandle(forWritingAtPath: filePath.path) else {
            return req.eventLoop.makeSucceededFuture(.internalServerError)
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

                let queryResult = Brunch.query(on: req.db)
                    .filter(\.$tag == tag)
                    .first()
                    .flatMap { brunch -> EventLoopFuture<Void> in
                        let brunchToSave = brunch ?? Brunch(tag: tag, filename: filename, tested: false, description: "")

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
            return req.eventLoop.makeSucceededFuture(Response(status: .badRequest))
        }

        let responseResult = Brunch.query(on: req.db)
            .filter(\.$tag == tag)
            .first()
            .flatMap { brunch -> EventLoopFuture<Response> in
                guard let brunch = brunch else {
                        return req.eventLoop.makeSucceededFuture(Response(status: .notFound))
                }

                // <a href="itms-services://?action=download-manifest&url=https://your.domain.com/your-app/manifest.plist">Awesome App</a>
                let response = req.redirect(to: "itms-services://?action=download-manifest&url=https://\(host)/install/\(brunch.tag)/manifest.plist", type: .temporary)
                return req.eventLoop.makeSucceededFuture(response)
            }

        return responseResult
    }


    // http://localhost:8080/install/PULSAR-1234/manifest.plist
    func installManifest(_ req: Request) throws -> EventLoopFuture<Response> {
        guard let tag = req.parameters.get("tag"),
        let host = req.headers.first(name: "Host") else {
            return req.eventLoop.makeSucceededFuture(Response(status: .badRequest))
        }

        let responseResult = Brunch.query(on: req.db)
            .filter(\.$tag == tag)
            .first()
            .flatMap { brunch -> EventLoopFuture<Response> in
                guard let filename = brunch?.filename else {
                        return req.eventLoop.makeSucceededFuture(Response(status: .notFound))
                }

                let manifestTemplate = R.manifest
                let manifest = manifestTemplate
                    .replacingOccurrences(of: "${DOMAIN}", with: host)
                    .replacingOccurrences(of: "${BRANCH_TAG}", with: tag)
                    .replacingOccurrences(of: "${FILE_NAME}", with: filename)
                    .replacingOccurrences(of: "${BUNDLE_IDENTIFIER}", with: "ru.mail.channel-alpha")
                    .replacingOccurrences(of: "${APPLICATION_VERSION}", with: "1.0")
                    .replacingOccurrences(of: "${DISPLAY_NAME}", with: "channel-alpha")

                let response = Response(status: .ok, body: Response.Body(string: manifest))

                return req.eventLoop.makeSucceededFuture(response)
            }

        return responseResult
    }
}
