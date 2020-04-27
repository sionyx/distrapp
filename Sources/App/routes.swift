import Fluent
import Vapor

func routes(_ app: Application) throws {
    app.get { req in
        return "It works!"
    }

    app.get("hello") { req -> String in
        return "Hello, world!"
    }

    let brunchesController = BrunchController()
    app.on(.GET, "branches", use: brunchesController.index)
    app.on(.POST, "upload", ":tag", ":filename", body: .stream, use: brunchesController.upload)
    app.on(.GET, "download", ":tag", use: brunchesController.download)

//    app.get("branch", Brunch.parameter, use: brunchesController.one)
//    app.get("new", use: brunchesController.createNew)
//    app.post("branches", use: brunchesController.create)
//    app.post("upload", use: brunchesController.upload)


    //    router.get("download", String.parameter, String.parameter, use: todoController.download)
    //    router.get("download", use: todoController.download)
    //app.delete("branches", Brunch.parameter, use: brunchesController.delete)
}
