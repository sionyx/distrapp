import Fluent
import Vapor

struct Controllers {
    let authController = AuthController()
    let usersController = UsersController()
    let projectsController = ProjectsController()
    let grantsController = GrantsController()
    let branchesController = BranchController()
    let installController = InstallController()

    private init() { }
    static var shared: Controllers = {
        Controllers()
    }()
}

func routes(_ app: Application) throws {
    app.get { req -> Response in
        guard let host = req.headers.first(name: "Host") else {
            throw Abort(.badRequest)
        }

        return req.redirect(to: "https://\(host)/docs/", type: .permanent)
    }


    let api = app.grouped("api")
    let apiV1 = api.grouped("v1")
    let tokenProtected = apiV1.grouped(UserToken.authenticator())


    directRoutes(app, Controllers.shared)
    unprotectedRoutes(apiV1, Controllers.shared)
    protectedRoutes(tokenProtected, Controllers.shared)
    #if DEBUG
    debugRoutes(app, Controllers.shared)
    #endif
}

func directRoutes(_ builder: RoutesBuilder, _ controllers: Controllers) {
    let install = builder.grouped("install")
    install.on(.GET, ":project", ":tag", use: controllers.installController.install)
    install.on(.GET, ":project", ":tag", "manifest.plist", use: controllers.installController.installManifest)

    let download = builder.grouped("download")
    download.on(.GET, ":project", ":tag", ":filename", use: controllers.installController.download)
}

func unprotectedRoutes(_ builder: RoutesBuilder, _ controllers: Controllers) {
    let auth = builder.grouped("auth")
    auth.on(.GET, "getcode", use: controllers.authController.getCode)
    auth.on(.GET, "gettoken", use: controllers.authController.getToken)
}

func protectedRoutes(_ builder: RoutesBuilder, _ controllers: Controllers) {
    let users = builder.grouped("users")
    users.on(.GET, "me", use: controllers.usersController.me)
    users.on(.POST, use: controllers.usersController.add)

    let projects = builder.grouped("projects")
    projects.on(.GET, use: controllers.projectsController.list)
    projects.on(.POST, use: controllers.projectsController.add)
    projects.on(.DELETE, use: controllers.projectsController.delete)

    let grants = builder.grouped("grants")
    grants.on(.GET, use: controllers.grantsController.list)
    grants.on(.POST, use: controllers.grantsController.add)
    grants.on(.DELETE, use: controllers.grantsController.delete)

    let branches = builder.grouped("branches")
    branches.on(.GET, use: controllers.branchesController.list)
    branches.on(.DELETE, use: controllers.branchesController.delete)

    let upload = builder.grouped("upload")
    upload.on(.POST, body: .stream, use: controllers.branchesController.upload)
}


// MARK: Debug routes
func debugRoutes(_ builder: RoutesBuilder, _ controllers: Controllers) {

    let userTokensController = UserTokensController()
    let _tokens = builder.grouped("tokens")
    _tokens.on(.GET, use: userTokensController._index)

    let _users = builder.grouped("users")
    _users.on(.GET, use: controllers.usersController._index)
    _users.on(.GET, ":id", use: controllers.usersController._one)
    _users.on(.DELETE, ":id", use: controllers.usersController._delete)

    let _projects = builder.grouped("projects")
    _projects.on(.GET, use: controllers.projectsController._index)
    _projects.on(.GET, ":id", use: controllers.projectsController._one)

    let _grants = builder.grouped("grants")
    _grants.on(.GET, use: controllers.grantsController._index)

    let _branches = builder.grouped("branches")
    _branches.on(.GET, use: controllers.branchesController._index)
}
