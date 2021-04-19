//
//  InstallController.swift
//  
//
//  Created by Вадим Балашов on 03.01.2021.
//

import Fluent
import Vapor

struct InstallController {
    // http://localhost:8080/install/SMOTRI/PULSAR-1234
    func install(_ req: Request) throws -> EventLoopFuture<Response> {
        guard let project = req.parameters.get("project"),
              let tag = req.parameters.get("tag"),
              let host = req.headers.first(name: "Host"),
              let ua = req.headers.first(name: "User-Agent") else {
            throw Abort(.badRequest)
        }

        let branch = Project
            .by(name: project, on: req.db)
            .branch(by: tag, on: req.db)

        return branch
            .map { project, branch -> Response in
                // <a href="itms-services://?action=download-manifest&url=https://your.domain.com/your-app/manifest.plist">Awesome App</a>
                let url: String
                if ua.contains("iPhone OS") {
                    url = "itms-services://?action=download-manifest&url=https://\(host)/install/\(project.name)/\(branch.tag)/manifest.plist"
                }
                else {
                    url = "http://\(host)/projects/\(project.name)/\(branch.tag)"
                }

                let response = req.redirect(to: url, type: .temporary)
                return response
            }
    }


    // http://localhost:8080/install/SMOTRI/PULSAR-1234/manifest.plist
    func installManifest(_ req: Request) throws -> EventLoopFuture<Response> {
        guard let project = req.parameters.get("project"),
              let tag = req.parameters.get("tag"),
              let host = req.headers.first(name: "Host") else {
            throw Abort(.badRequest)
        }

        let branch = Project
            .by(name: project, on: req.db)
            .branch(by: tag, on: req.db)

        return branch
            .map { project, branch -> Response in
                let manifestTemplate = R.manifest
                let manifest = manifestTemplate
                    .replacingOccurrences(of: "${DOMAIN}", with: host)
                    .replacingOccurrences(of: "${PROJECT_NAME}", with: project.name)
                    .replacingOccurrences(of: "${BRANCH_TAG}", with: branch.tag)
                    .replacingOccurrences(of: "${FILE_NAME}", with: branch.filename)
                    .replacingOccurrences(of: "${APPLICATION_VERSION}", with: "1.0")
                    .replacingOccurrences(of: "${BUNDLE_IDENTIFIER}", with: project.bundleId)
                    .replacingOccurrences(of: "${DISPLAY_NAME}", with: project.title)

                let response = Response(status: .ok, body: Response.Body(string: manifest))
                return response
            }
    }

    // http://localhost:8080/download/SMOTRI/PULSAR-1234/app.ipa
    func download(_ req: Request) throws -> EventLoopFuture<Response> {
        guard let project = req.parameters.get("project"),
              let tag = req.parameters.get("tag") else {
            throw Abort(.badRequest)
        }

        let branch = Project
            .by(name: project, on: req.db)
            .branch(by: tag, on: req.db)

        let responseResult = branch
            .flatMapThrowing { project, branch -> Response in
                let filePath = URL(fileURLWithPath: "./builds/\(project.name)/\(branch.tag)/\(branch.filename)")

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

}
