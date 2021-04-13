import Fluent
import Vapor
import Leaf

struct Controllers {
    let authController = AuthController()
    let usersController = UsersController()
    let projectsController = ProjectsController()
    let grantsController = GrantsController()
    let branchesController = BranchController()
    let installController = InstallController()
    let websiteController = WebsiteController()

    private init() { }
    static var shared: Controllers = {
        Controllers()
    }()
}

func routes(_ app: Application) throws {
    let api = app.grouped("api")
    let apiV1 = api.grouped("v1")
    let tokenProtected = apiV1.grouped(UserToken.authenticator())
    let sessioned = app.grouped(app.sessions.middleware).grouped(User.sessionAuthenticator())
    let sessionProtected = sessioned.grouped(User.redirectMiddleware(path: "/login?loginRequired=1"))


    directRoutes(app, Controllers.shared)
    unprotectedRoutes(apiV1, Controllers.shared)
    protectedRoutes(tokenProtected, Controllers.shared)

    websiteRoutes(sessioned, Controllers.shared)
    sessionRoutes(sessionProtected, Controllers.shared)

    #if DEBUG
    let debug = app.grouped("debug")
    debugRoutes(debug, Controllers.shared)
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
    projects.on(.PUT, use: controllers.projectsController.update)
    projects.on(.DELETE, use: controllers.projectsController.delete)

    let grants = builder.grouped("grants")
    grants.on(.GET, use: controllers.grantsController.list)
    grants.on(.POST, use: controllers.grantsController.add)
    grants.on(.DELETE, use: controllers.grantsController.delete)

    let branches = builder.grouped("branches")
    branches.on(.GET, use: controllers.branchesController.list)
    branches.on(.PUT, use: controllers.branchesController.update)
    branches.on(.DELETE, use: controllers.branchesController.delete)

    let upload = builder.grouped("upload")
    upload.on(.POST, body: .stream, use: controllers.branchesController.upload)
}

func websiteRoutes(_ builder: RoutesBuilder, _ controllers: Controllers) {
    builder.on(.GET, use: controllers.websiteController.indexHandler)
    builder.on(.GET, "login", use: controllers.websiteController.loginHandler)
    builder.grouped(User.credentialsAuthenticator())
           .on(.POST, "login", use: controllers.websiteController.loginDoneHandler)
    builder.on(.GET, "signup", use: controllers.websiteController.signupHandler)
    builder.on(.POST, "signup", use: controllers.websiteController.signupDoneHandler)
    builder.on(.POST, "logout", use: controllers.websiteController.logoutHandler)

    builder.on(.GET, "projects", ":project", ":branch", use: controllers.websiteController.branchHandler)
}

func sessionRoutes(_ builder: RoutesBuilder, _ controllers: Controllers) {
    builder.on(.GET, "profile", use: controllers.websiteController.profileHandler)
    builder.on(.GET, "changepassword", use: controllers.websiteController.changePasswordHandler)
    builder.on(.POST, "changepassword", use: controllers.websiteController.changePasswordDoneHandler)

    builder.on(.GET, "projects", use: controllers.websiteController.projectsHandler)
    builder.on(.GET, "projects", ":project", use: controllers.websiteController.branchesHandler)
    builder.on(.GET, "projects", ":project", "upload", use: controllers.websiteController.uploadHandler)
    builder.on(.GET, "projects", ":project", ":branch", "upload", use: controllers.websiteController.uploadHandler)
    builder.on(.POST, "projects", ":project", "upload", use: controllers.websiteController.uploadDoneHandler)
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
