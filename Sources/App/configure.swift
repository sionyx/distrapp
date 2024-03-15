import Fluent
import FluentPostgresDriver
import Vapor
import QueuesFluentDriver
import Leaf

// configures your application
public func configure(_ app: Application) throws {
//    let hostname = Environment.get("DATABASE_HOST")!
//    let username = Environment.get("DATABASE_USERNAME")!
//    let password = Environment.get("DATABASE_PASSWORD")!
//    let database = Environment.get("DATABASE_NAME")!
//    let myteamToken = Environment.get("MYTEAM_TOKEN")!

    let hostname = Environment.get("DATABASE_HOST") ?? "localhost"
    let username = Environment.get("DATABASE_USERNAME") ?? "vapor_username"
    let password = Environment.get("DATABASE_PASSWORD") ?? "vapor_password"
    let database = Environment.get("DATABASE_NAME") ?? "wallet_db"
    let myteamToken = Environment.get("MYTEAM_TOKEN") //?? "001.1826685345.0997361462:1000000771"

    print("hostname: \(hostname)")
    print("username: \(username)")
    print("password: \(password.prefix(3))***\(password.suffix(3))")
    print("database: \(database)")
    if let myteamToken {
        print("myteam token: \(myteamToken.prefix(15))***\(myteamToken.suffix(11))")
    }

    app.http.server.configuration.hostname = "0.0.0.0"
    app.http.server.configuration.port = 8080

    app.databases.use(.postgres(
        hostname: Environment.get("DATABASE_HOST") ?? "localhost",
        port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? PostgresConfiguration.ianaPortNumber,
        username: Environment.get("DATABASE_USERNAME") ?? "vapor_username",
        password: Environment.get("DATABASE_PASSWORD") ?? "vapor_password",
        database: Environment.get("DATABASE_NAME") ?? "wallet_db"
    ), as: .psql)

    app.migrations.add(CreateUsers())
    app.migrations.add(CreateProjects())
    app.migrations.add(CreateGrants())
    app.migrations.add(CreateBranches())
    app.migrations.add(CreateUserToken())
    app.migrations.add(CreateOneTimeCodes())
    app.migrations.add(SessionRecord.migration)
    app.migrations.add(UserPassword())

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
    app.routes.defaultMaxBodySize = "512mb"

    app.sessions.use(.fluent)
    app.views.use(.leaf)

    // MyTeam Bot
    if let myteamToken {
        MyTeam.Configuration.token = myteamToken
        let botListener = app.myTeamListener
        botListener.configure(with: [ MyTeam.PingHandler(),
                                      MyTeam.StartHandler() ])
        botListener.listen()
    }
}

