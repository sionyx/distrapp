//
//  ProfileWebController.swift
//  
//
//  Created by Вадим Балашов on 18.04.2021.
//

import Vapor
import Leaf
import Fluent

struct ProfileWebController {
    func profileHandler(_ req: Request) throws -> EventLoopFuture<View> {
        guard let currentUser = try? req.auth.require(User.self),
              let currentUserId = currentUser.id else {
            throw Abort(.unauthorized)
        }

        return UserToken.query(on: req.db)
            .filter(\.$user.$id == currentUserId)
            .all()
            .mapEachCompact { $0.secure }
            .flatMap { tokens in
                req.view.render("profile", ProfileContent(user: currentUser.short,
                                                          tokens: tokens))
            }
    }


    //MARK: Sign Up

    func signupHandler(_ req: Request) throws -> EventLoopFuture<View> {
        let user = try? req.auth.require(User.self)
        if user != nil {
            throw Abort.redirect(to: "/profile")
        }

        let firstName = req.session.data["firstName"]
        let lastName = req.session.data["lastName"]
        let email = req.session.data["email"]
        let invalidFirstName = req.session.data["validFirstName"] == "false"
        let invalidLastName = req.session.data["validLastName"] == "false"
        let invalidEmail = req.session.data["validEmail"] == "false"
        let invalidPassword = req.session.data["validPassword"] == "false"

        return req.view.render("signup", SignupContent(user: user?.short,
                                                       firstName: firstName,
                                                       lastName: lastName,
                                                       email: email,
                                                       invalidFirstName: invalidFirstName,
                                                       invalidLastName: invalidLastName,
                                                       invalidEmail: invalidEmail,
                                                       invalidPassword: invalidPassword))
    }

    func signupDoneHandler(_ req: Request) throws -> EventLoopFuture<Response> {
        guard let params = try? req.content.decode(SignupParams.self) else {
            throw Abort.redirect(to: "/signup")
        }

        let validFirstName = params.firstName.count >= 2
        let validLastName = params.lastName.count >= 2
        let validEmail = params.email.isValidEmail
        let validPassword = params.password.isValidPassword

        req.session.data["firstName"] = params.firstName
        req.session.data["lastName"] = params.lastName
        req.session.data["email"] = params.email
        req.session.data["validFirstName"] = validFirstName ? "true" : "false"
        req.session.data["validLastName"] = validLastName ? "true" : "false"
        req.session.data["validEmail"] = validEmail ? "true" : "false"
        req.session.data["validPassword"] = validPassword ? "true" : "false"

        guard validEmail,
              validPassword,
              validFirstName,
              validLastName,
              let digest = try? Bcrypt.hash(params.password) else {
            return try signupHandler(req).encodeResponse(for: req)
        }

        return User.query(on: req.db)
            .filter(\.$authId == params.email)
            .first()
            .flatMap { user in
                if user != nil {
                    return req.eventLoop.makeSucceededFuture(req.redirect(to: "/login?email=\(params.email)"))
                }
                let user = User(firstName: params.firstName,
                                lastName: params.lastName,
                                authProvider: "site",
                                authId: params.email,
                                password: digest)
                let save = user.create(on: req.db)

                save.whenComplete({ _ in
                    req.auth.login(user)
                })

                return save.transform(to: req.redirect(to: "/profile"))
            }
    }


    //MARK: Login

    func loginHandler(_ req: Request) throws -> EventLoopFuture<View> {
        let user = try? req.auth.require(User.self)
        if user != nil {
            throw Abort.redirect(to: "/profile")
        }

        let email = req.session.data["email"]
        let invalid = req.session.data["invalidEmailOrPass"] == "true"


        let params = try? req.query.decode(LoginParams.self)
        return req.view.render("login", LoginContent(user: user?.short,
                                                     path: params?.path,
                                                     email: email ?? params?.email,
                                                     loginRequired: params?.loginRequired != nil,
                                                     invalid: invalid || params?.invalid != nil))
    }

    func loginDoneHandler(_ req: Request) throws -> EventLoopFuture<Response> {
        guard let user = try? req.auth.require(User.self) else {
            let params = try? req.content.decode(LoginDoneParams.self)
            req.session.data["email"] = params?.username
            req.session.data["invalidEmailOrPass"] = "true"
            return try loginHandler(req).encodeResponse(for: req)
        }

        if user.password == "" {
            return req.eventLoop.makeSucceededFuture(req.redirect(to: "/changepassword"))
        }

        if let params = try? req.query.decode(LoginParams.self),
           let path = params.path {
            return req.eventLoop.makeSucceededFuture(req.redirect(to: path))
        }

        return req.eventLoop.makeSucceededFuture(req.redirect(to: "/projects"))
    }


    //MARK: Change Password

    func changePasswordHandler(_ req: Request) throws -> EventLoopFuture<View> {
        guard let user = try? req.auth.require(User.self) else {
            throw Abort(.unauthorized)
        }

        return req.view.render("changepassword", ChangePasswordContent(user: user.short))
    }

    func changePasswordDoneHandler(_ req: Request) throws -> EventLoopFuture<Response> {
        guard let user = try? req.auth.require(User.self),
              let params = try? req.content.decode(NewPassParams.self) else {
            throw Abort(.badRequest)
        }

        guard params.password == params.password2,
              params.password.isValidPassword,
              let digest = try? Bcrypt.hash(params.password) else {
            throw Abort.redirect(to: "/changepassword")
        }

        user.password = digest
        return user.save(on: req.db)
            .transform(to: req.redirect(to: "/profile"))
    }


    //MARK: Logout
    
    func logoutHandler(_ req: Request) throws -> Response {
        req.auth.logout(User.self)
        req.session.destroy()
        return req.redirect(to: "/")
    }


    // MARK: Tokens
    func createTokenDoneHandler(_ req: Request) throws -> EventLoopFuture<Response> {
        guard let user = try? req.auth.require(User.self) else {
            throw Abort(.unauthorized)
        }

        guard let params = try? req.content.decode(CreateTokenParams.self),
              params.place.count >= 3 else {
            throw Abort(.badRequest, reason: "Token must be at least 3 characters long")
        }

        guard let userToken = try? user.generateToken(place: params.place) else {
            throw Abort(.internalServerError, reason: "Token Cannot Be Generated")
        }

        return userToken
            .save(on: req.db)
            .transform(to: req.redirect(to: "/profile"))
    }

    func revokeTokenDoneHandler(_ req: Request) throws -> EventLoopFuture<Response> {
        guard let user = try? req.auth.require(User.self) else {
            throw Abort(.unauthorized)
        }

        guard let params = try? req.content.decode(RevokeTokenParams.self),
              let tokenId = UUID(uuidString: params.token) else {
            throw Abort(.badRequest)
        }

        return UserToken.query(on: req.db)
            .filter(\.$id == tokenId)
            .with(\.$user)
            .first()
            .unwrap(or: Abort(.badRequest, reason: "Token Not Found"))
            .guard( { $0.user.id == user.id }, else: Abort(.badRequest, reason: "Invalis User Token"))
            .flatMap { token in
                token.delete(force: true, on: req.db)
            }
            .transform(to: req.redirect(to: "/profile"))
    }
}


struct LoginContent: WebSiteContent {
    var title = "Login"
    let user: User.Short?
    let path: String?
    let email: String?
    let loginRequired: Bool
    let invalid: Bool
}

struct SignupContent: WebSiteContent {
    var title = "Sign Up"
    let user: User.Short?
    let firstName: String?
    let lastName: String?
    let email: String?
    let invalidFirstName: Bool?
    let invalidLastName: Bool?
    let invalidEmail: Bool?
    let invalidPassword: Bool?
}

struct ProfileContent: WebSiteContent {
    var title = "Profile"
    let user: User.Short?
    let tokens: [UserToken.Secure]
}

struct ChangePasswordContent: WebSiteContent {
    var title = "Change Password"
    let user: User.Short?
}

struct LoginParams: Content {
    let email: String?
    let path: String?
    let loginRequired: Int?
    let invalid: Int?
}

struct LoginDoneParams: Content {
    let username: String
}

struct NewPassParams: Content {
    let password: String
    let password2: String
}

struct SignupParams: Content {
    let firstName: String
    let lastName: String
    let email: String
    let password: String
}

struct CreateTokenParams: Content {
    let place: String
}

struct RevokeTokenParams: Content {
    let token: String
}
