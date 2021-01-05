import Fluent

struct CreateProjects: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("projects")
            .id()
            .field("name", .string, .required)
            .field("created", .datetime, .required)
            .field("updated", .datetime, .required)
            .field("title", .string, .required)
            .field("bundle_id", .string, .required)
            .field("description", .string)
            .field("icon", .string)
            .field("telegram_token", .string)
            .field("telegram_id", .string)
            .field("myteam_token", .string)
            .field("myteam_url", .string)
            .field("myteam_id", .string)
            .unique(on: "name", "bundle_id")
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("projects").delete()
    }
}
