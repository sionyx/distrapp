import Fluent
import Vapor
import Leaf

enum Controllers {
    enum API {
        static let authController = AuthController()
        static let usersController = UsersController()
        static let projectsController = ProjectsController()
        static let grantsController = GrantsController()
        static let branchesController = BranchController()
        static let installController = InstallController()
    }

    enum Web {
        static let websiteController = WebsiteController()
        static let profileController = ProfileWebController()
        static let projectsController = ProjectsWebController()
        static let branchesController = BranchesWebController()
        static let grantsController = GrantsWebController()
    }
}

func routes(_ app: Application) throws {
    let api = app.grouped("api")
    let apiV1 = api.grouped("v1")
    let tokenProtected = apiV1.grouped(UserToken.authenticator())
    let sessioned = app.grouped(app.sessions.middleware).grouped(User.sessionAuthenticator())
    let sessionProtected = sessioned.grouped(User.redirectMiddleware(makePath: { req -> String in
        "/login?loginRequired=1&path=\(req.url.path)"
    }))

    directRoutes(app)
    unprotectedRoutes(apiV1)
    protectedRoutes(tokenProtected)

    websiteRoutes(sessioned)
    sessionRoutes(sessionProtected)

    #if DEBUG
    let debug = app.grouped("debug")
    debugRoutes(debug)
    #endif
}

func directRoutes(_ builder: RoutesBuilder) {
    let install = builder.grouped("install")
    install.on(.GET, ":project", ":tag", use: Controllers.API.installController.install)
    install.on(.GET, ":project", ":tag", "manifest.plist", use: Controllers.API.installController.installManifest)

    let download = builder.grouped("download")
    download.on(.GET, ":project", ":tag", ":filename", use: Controllers.API.installController.download)
}

func unprotectedRoutes(_ builder: RoutesBuilder) {
    let auth = builder.grouped("auth")
    auth.on(.GET, "getcode", use: Controllers.API.authController.getCode)
    auth.on(.GET, "gettoken", use: Controllers.API.authController.getToken)
}

func protectedRoutes(_ builder: RoutesBuilder) {
    let users = builder.grouped("users")
    users.on(.GET, "me", use: Controllers.API.usersController.me)
    users.on(.POST, use: Controllers.API.usersController.add)

    let projects = builder.grouped("projects")
    projects.on(.GET, use: Controllers.API.projectsController.list)
    projects.on(.POST, use: Controllers.API.projectsController.add)
    projects.on(.PUT, use: Controllers.API.projectsController.update)
    projects.on(.DELETE, use: Controllers.API.projectsController.delete)

    let grants = builder.grouped("grants")
    grants.on(.GET, use: Controllers.API.grantsController.list)
    grants.on(.POST, use: Controllers.API.grantsController.add)
    grants.on(.DELETE, use: Controllers.API.grantsController.delete)

    let branches = builder.grouped("branches")
    branches.on(.GET, use: Controllers.API.branchesController.list)
    branches.on(.PUT, use: Controllers.API.branchesController.update)
    branches.on(.DELETE, use: Controllers.API.branchesController.delete)

    let upload = builder.grouped("upload")
    upload.on(.POST, body: .stream, use: Controllers.API.branchesController.upload)
}

func websiteRoutes(_ builder: RoutesBuilder) {
    builder.on(.GET, use: Controllers.Web.websiteController.indexHandler)
    builder.on(.GET, "login", use: Controllers.Web.profileController.loginHandler)
    builder.grouped(User.credentialsAuthenticator())
           .on(.POST, "login", use: Controllers.Web.profileController.loginDoneHandler)
    builder.on(.GET, "signup", use: Controllers.Web.profileController.signupHandler)
    builder.on(.POST, "signup", use: Controllers.Web.profileController.signupDoneHandler)
    builder.on(.POST, "logout", use: Controllers.Web.profileController.logoutHandler)

    builder.on(.GET, "projects", ":project", ":branch", use: Controllers.Web.branchesController.branchHandler)
}

func sessionRoutes(_ builder: RoutesBuilder) {
    builder.on(.GET, "profile", use: Controllers.Web.profileController.profileHandler)
    builder.on(.GET, "changepassword", use: Controllers.Web.profileController.changePasswordHandler)
    builder.on(.POST, "changepassword", use: Controllers.Web.profileController.changePasswordDoneHandler)

    builder.on(.GET, "projects", use: Controllers.Web.projectsController.projectsHandler)
    builder.on(.GET, "projects", ":project", use: Controllers.Web.branchesController.branchesHandler)

    builder.on(.GET, "projects", "new", use: Controllers.Web.projectsController.newProject)
    builder.on(.POST, "projects", "new", use: Controllers.Web.projectsController.newProjectDone)
    builder.on(.GET, "projects", ":project", "edit", use: Controllers.Web.projectsController.editProject)
    builder.on(.POST, "projects", ":project", "save", use: Controllers.Web.projectsController.editProjectDone)
    builder.on(.POST, "projects", ":project", "icon", use: Controllers.Web.projectsController.iconProjectDone)
    builder.on(.GET, "projects", ":project", "delete", use: Controllers.Web.projectsController.deleteProject)
    builder.on(.POST, "projects", ":project", "delete", use: Controllers.Web.projectsController.deleteProjectDone)
    builder.on(.GET, "projects", ":project", "members", use: Controllers.Web.grantsController.membersHandler)
    builder.on(.POST, "projects", ":project", "invite", use: Controllers.Web.grantsController.inviteDone)
    builder.on(.POST, "projects", ":project", "remove", use: Controllers.Web.grantsController.removeDone)

    builder.on(.GET, "projects", ":project", "upload", use: Controllers.Web.branchesController.uploadHandler)
    builder.on(.GET, "projects", ":project", ":branch", "upload", use: Controllers.Web.branchesController.uploadHandler)
    builder.on(.POST, "projects", ":project", "upload", use: Controllers.Web.branchesController.uploadDoneHandler)
}



// MARK: Debug routes
func debugRoutes(_ builder: RoutesBuilder) {

    let userTokensController = UserTokensController()
    let _tokens = builder.grouped("tokens")
    _tokens.on(.GET, use: userTokensController._index)

    let _users = builder.grouped("users")
    _users.on(.GET, use: Controllers.API.usersController._index)
    _users.on(.GET, ":id", use: Controllers.API.usersController._one)
    _users.on(.DELETE, ":id", use: Controllers.API.usersController._delete)

    let _projects = builder.grouped("projects")
    _projects.on(.GET, use: Controllers.API.projectsController._index)
    _projects.on(.GET, ":id", use: Controllers.API.projectsController._one)

    let _grants = builder.grouped("grants")
    _grants.on(.GET, use: Controllers.API.grantsController._index)

    let _branches = builder.grouped("branches")
    _branches.on(.GET, use: Controllers.API.branchesController._index)
}
