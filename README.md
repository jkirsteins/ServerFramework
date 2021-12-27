# ServerFramework

A Swift framework for writing APIs.

# Getting Started

Specify the dependency in your `Package.swift` file:

    .package(url: "https://github.com/jkirsteins/ServerFramework.git", from: "0.1.0")
    
And add the required dependencies to your app target:

    // Main dependency
    .product(name: "ServerFramework", package: "ServerFramework"),
    
    // Include this if you want to run a standalone server...
    .product(name: "ServerFrameworkNIO", package: "ServerFramework"),
    
    // ... or include this if you want to run inside a Lambda environment.
    .product(name: "ServerFrameworkLambda", package: "ServerFramework"),
    
    
Now initialize your application

    import ServerFramework
    import ServerFrameworkNIO

    // Create the base dependency container
    let appDependencies = Dependencies()
    
    // You can register your initial dependencies on startup for use later
    appDependencies.register(instance: "Hello World")

    SwiftNioLauncher().run(dependencyProvider: appDependencies) { realDeps in
        let api = App(dependencies: realDeps)
        
        api.get("/") { (req, res, deps, next) in
            // - req contains request data (body, headers or query params)
            // - res allows sending a response
            // - deps allow looking up a dependency
            // - next is used to pass execution to the next middleware (not
            //     needed in get/post request handlers)
            
            // Retrieve dependency from `realDeps`
            // The difference between `appDependencies` and `realDeps` is that
            // the latter contains dependencies registered by the launcher.
            //
            // So if you e.g. need access to the launcher's EventLoopGroup, 
            // you need to use the dependency container received from the launcher.
            let message: String = realDeps.resolveRequired()
            
            res.json(message, status: 200)
        }
        
        return api
    }

## Different launchers

`SwiftNioLauncher` in the previous example conforms to `ServerFramework.Launcher` protocol.

Other launchers include:

  - `ServerFrameworkLambda.LambdaLauncher` for running a Lambda
  - `ServerFrameworkXCTest.TestLauncher` for use in tests (it will process requests, 
    and provide access to the response, without instantiating an actual server) 

## Dependencies

There is a `Dependencies` class. It is a simple wrapper around Swinject currently. 
