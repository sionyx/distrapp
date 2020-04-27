import Fluent
import FluentMySQLDriver
import Vapor

// configures your application
public func configure(_ app: Application) throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    let config = MySQLConfiguration(hostname: Environment.get("DATABASE_HOST")!,
                                    port: 3306,
                                    username: Environment.get("DATABASE_USERNAME")!,
                                    password: Environment.get("DATABASE_PASSWORD")!,
                                    database: Environment.get("DATABASE_NAME")!,
                                    tlsConfiguration: .forClient(certificateVerification: .none))

    app.databases.use(.mysql(configuration: config, maxConnectionsPerEventLoop: 8), as: .mysql)
    app.migrations.add(CreateBranches())

    // register routes
    try routes(app)
}
