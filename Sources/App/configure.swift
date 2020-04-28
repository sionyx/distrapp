import Fluent
import FluentMySQLDriver
import Vapor

// configures your application
public func configure(_ app: Application) throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    let hostname = Environment.get("DATABASE_HOST")!
    let username = Environment.get("DATABASE_USERNAME")!
    let password = Environment.get("DATABASE_PASSWORD")!
    let database = Environment.get("DATABASE_NAME")!

    print("hostname: \(hostname)")
    print("username: \(username)")
    print("password: \(password.prefix(3))***\(password.suffix(3))")
    print("database: \(database)")

    let config = MySQLConfiguration(hostname: hostname,
                                    port: 3306,
                                    username: username,
                                    password: password,
                                    database: database,
                                    tlsConfiguration: .forClient(certificateVerification: .none))

    app.databases.use(.mysql(configuration: config, maxConnectionsPerEventLoop: 8), as: .mysql)
    app.migrations.add(CreateBranches())

    // register routes
    try routes(app)
}
