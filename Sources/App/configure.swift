import Fluent
import FluentMySQLDriver
import Vapor
import QueuesFluentDriver
import Leaf

// configures your application
public func configure(_ app: Application) throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    let hostname = Environment.get("DATABASE_HOST")!
    let username = Environment.get("DATABASE_USERNAME")!
    let password = Environment.get("DATABASE_PASSWORD")!
    let database = Environment.get("DATABASE_NAME")!
    let myteamToken = Environment.get("MYTEAM_TOKEN")!

    print("hostname: \(hostname)")
    print("username: \(username)")
    print("password: \(password.prefix(3))***\(password.suffix(3))")
    print("database: \(database)")
    print("myteam token: \(myteamToken.prefix(15))***\(myteamToken.suffix(11))")

    let config = MySQLConfiguration(hostname: hostname,
                                    port: 3306,
                                    username: username,
                                    password: password,
                                    database: database,
                                    tlsConfiguration: .forClient(certificateVerification: .none))

    MyTeam.Configuration.token = myteamToken

    app.http.server.configuration.hostname = "127.0.0.1"
    app.http.server.configuration.port = 8080

    app.databases.use(.mysql(configuration: config, maxConnectionsPerEventLoop: 8), as: .mysql)
    app.migrations.add(CreateUsers())
    app.migrations.add(CreateProjects())
    app.migrations.add(CreateGrants())
    app.migrations.add(CreateBranches())
    app.migrations.add(CreateUserToken())
    app.migrations.add(CreateOneTimeCodes())
    app.migrations.add(SessionRecord.migration)

    // Queues
    app.migrations.add(JobModelMigrate())
    app.queues.use(.fluent(useSoftDeletes: false))

    // Middleware
    let corsConfiguration = CORSMiddleware.Configuration(
        allowedOrigin: .all,
        allowedMethods: [.GET, .POST, .PUT, .OPTIONS, .DELETE, .PATCH],
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith, .userAgent, .accessControlAllowOrigin]
    )
    let cors = CORSMiddleware(configuration: corsConfiguration)


    // Clear any existing middleware.
    app.middleware = .init()
    app.middleware.use(cors)
    app.middleware.use(ErrorMiddleware.default(environment: app.environment))
    app.middleware.use(FileMiddleware(publicDirectory: "Public"))

    // register routes
    try routes(app)

    app.sessions.use(.fluent)
    app.views.use(.leaf)

    // MyTeam Bot
    let botListener = app.myTeamListener
    botListener.configure(with: [ MyTeam.PingHandler(),
                                  MyTeam.StartHandler() ])
    botListener.listen()
}

