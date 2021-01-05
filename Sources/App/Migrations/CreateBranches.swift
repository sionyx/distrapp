import Fluent

struct CreateBranches: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("branches")
            .id()
            .field("project_id", .uuid, .required, .references("projects", "id"))
            .field("tag", .string, .required)
            .field("created", .datetime, .required)
            .field("updated", .datetime, .required)
            .field("filename", .string, .required)
            .field("size", .int32, .required)
            .field("is_tested", .bool, .required)
            .field("is_protected", .bool, .required)
            .field("description", .string)
            .field("build_number", .int32, .required)
            .unique(on: "project_id", "tag")
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("branches").delete()
    }
}
