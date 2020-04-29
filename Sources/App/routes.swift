import Fluent
import Vapor

func routes(_ app: Application) throws {
    app.get { req in
        return "It works!"
    }

    app.get("hello") { req -> String in
        return "Hello, world!"
    }

    let branchesController = BranchController()
    app.on(.GET, "branches", use: branchesController.index)
    app.on(.GET, "branch", ":tag", use: branchesController.one)
    app.on(.DELETE, "branch", ":tag", use: branchesController.delete)

    app.on(.POST, "upload", ":tag", ":filename", body: .stream, use: branchesController.upload)
    app.on(.GET, "download", ":tag", use: branchesController.download)
    app.on(.GET, "download", ":tag", ":filename", use: branchesController.download)
    app.on(.GET, "install", ":tag", use: branchesController.install)
    app.on(.GET, "install", ":tag", "manifest.plist", use: branchesController.installManifest)
}
