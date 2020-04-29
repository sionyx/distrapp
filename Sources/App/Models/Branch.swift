import Fluent
import Vapor

final class Branch: Model, Content {
    static let schema = "brunches"
    
    @ID(key: .id)
    var id: UUID?

    @Field(key: "tag")
    var tag: String

    @Field(key: "filename")
    var filename: String

    @Timestamp(key: "created", on: .create)
    var created: Date?

    @Timestamp(key: "updated", on: .update)
    var updated: Date?

    @Field(key: "tested")
    var tested: Bool

    @Field(key: "description")
    var description: String


    init() { }

    init(id: UUID? = nil, tag: String, filename: String, tested: Bool, description: String, created: Date? = nil, updated: Date? = nil) {
        self.id = id
        self.tag = tag
        self.filename = filename
        self.created = created
        self.updated = updated
        self.tested = tested
        self.description = description
    }
}

//extension Brunch: Parameter {
//    public static func resolveParameter(_ parameter: String, on container: Container) throws -> Future<Brunch> {
//        return container.requestPooledConnection(to: .mysql).flatMap { conn in
//            return Brunch.query(on: conn)
//                       .filter(\.tag == parameter)
//                       .first()
//                       .unwrap(or: Abort(.notFound, reason: "Unable to find brunch by provided tag"))
//                       .always {
//                try? container.releasePooledConnection(conn, to: .mysql)
//            }
//        }
//    }
//}
