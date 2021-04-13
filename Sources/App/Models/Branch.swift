import Fluent
import Vapor

final class Branch: Model {
    static let schema = "branches"
    
    @ID(key: .id)
    var id: UUID?

    @Parent(key: "project_id")
    var project: Project

    @Field(key: "tag")
    var tag: String

    @Timestamp(key: "created", on: .create)
    var created: Date?

    @Timestamp(key: "updated", on: .update)
    var updated: Date?

    @Field(key: "filename")
    var filename: String

    @Field(key: "size")
    var size: Int

    @Field(key: "is_tested")
    var isTested: Bool

    @Field(key: "is_protected")
    var isProtected: Bool

    @OptionalField(key: "description")
    var description: String?

    @Field(key: "build_number")
    var buildNumber: Int


    init() { }

    init(id: UUID? = nil, project: Project, tag: String, filename: String, size: Int, isTested: Bool, isProtected: Bool, description: String?, buildNumber: Int, created: Date? = nil, updated: Date? = nil) throws {
        self.id = id
        self.$project.id = try project.requireID()
        self.tag = tag
        self.created = created
        self.updated = updated
        self.filename = filename
        self.size = size
        self.isTested = isTested
        self.isProtected = isProtected
        self.description = description
        self.buildNumber = buildNumber
    }
}

extension Branch {
    struct Short: Content {
        let tag: String
        let created: Int
        let updated: Int
        let filename: String
        let size: Int
        let isTested: Bool
        let isProtected: Bool
        let description: String?
        let buildNumber: Int

        fileprivate init(_ branch: Branch) {
            self.tag = branch.tag
            self.created = Int(branch.created?.timeIntervalSince1970 ?? 0)
            self.updated = Int(branch.updated?.timeIntervalSince1970 ?? 0)
            self.filename = branch.filename
            self.size = branch.size
            self.isTested = branch.isTested
            self.isProtected = branch.isProtected
            self.description = branch.description
            self.buildNumber = branch.buildNumber
        }

        private enum CodingKeys: String, CodingKey {
            case tag
            case created
            case updated
            case filename
            case size
            case isTested = "is_tested"
            case isProtected = "is_protected"
            case description
            case buildNumber = "build_number"
        }
    }

    var short: Short {
        Short(self)
    }
}

struct GetBranchParams: Content {
    let project: String
    let branch: String
}

struct PostBranchParams: Content {
    let project: String
    let branch: String
    let filename: String
    let description: String?
}

struct PutBranchParams: Content {
    let project: String
    let branch: String
    let isTested: Bool?
    let isProtected: Bool?
    let description: String?

    private enum CodingKeys: String, CodingKey {
        case project
        case branch
        case isTested = "is_tested"
        case isProtected = "is_protected"
        case description
    }
}

extension EventLoopFuture where Value == Project {
    func branch(by tag: String, on db: Database) -> EventLoopFuture<(Project, Branch)> {
        self
            .flatMap { project -> EventLoopFuture<(Project, Branch)> in
                return project.$branches.query(on: db)
                    .filter(\.$tag == tag)
                    .first()
                    .unwrap(or: Abort(.notFound, reason: "Branch Not Found"))
                    .map { (project, $0) }
            }
    }
    func branchOrNot(by tag: String, on db: Database) -> EventLoopFuture<(Project, Branch?)> {
        self
            .flatMap { project -> EventLoopFuture<(Project, Branch?)> in
                return project.$branches.query(on: db)
                    .filter(\.$tag == tag)
                    .first()
                    .map { (project, $0) }
            }
    }
}

extension EventLoopFuture where Value == (Project, GrantType) {
    func branch(by tag: String, on db: Database) -> EventLoopFuture<(Project, GrantType, Branch)> {
        self
            .flatMap { project, grant -> EventLoopFuture<(Project, GrantType, Branch)> in
                return project.$branches.query(on: db)
                    .filter(\.$tag == tag)
                    .first()
                    .unwrap(or: Abort(.notFound, reason: "Branch Not Found"))
                    .map { (project, grant, $0) }
            }
    }
}

extension EventLoopFuture where Value == (Project, GrantType?) {
    func branch(by tag: String, on db: Database) -> EventLoopFuture<(Project, GrantType?, Branch)> {
        self
            .flatMap { project, grant -> EventLoopFuture<(Project, GrantType?, Branch)> in
                return project.$branches.query(on: db)
                    .filter(\.$tag == tag)
                    .first()
                    .unwrap(or: Abort(.notFound, reason: "Branch Not Found"))
                    .map { (project, grant, $0) }
            }
    }
}
