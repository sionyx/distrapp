import Fluent

struct CreateBranches: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("brunches")
            .id()
            .field("tag", .string, .required)
            .field("filename", .string, .required)
            .field("created", .datetime, .required)
            .field("updated", .datetime, .required)
            .field("tested", .bool, .required)
            .field("description", .string, .required)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("brunches").delete()
    }
}
