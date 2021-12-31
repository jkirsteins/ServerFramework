//
//  File.swift
//  
//
//  Created by Janis Kirsteins on 31/12/2021.
//

import Lifecycle
import Logging

public class BackgroundTaskScheduler
{
    enum Error : Swift.Error, CustomStringConvertible
    {
        case invalidStateForNewTasks
        
        var description: String {
            switch(self) {
            case .invalidStateForNewTasks:
                return "Lifecycle state does not support adding new tasks."
            }
        }
    }
    
    let logger = Logger.create(for: BackgroundTaskScheduler.self)
    
    var hasTerminated = false
    var shouldTerminate = false
    
    public typealias TaskType = (@Sendable () async -> Void)
    
    var taskQueue: [TaskType] = []
    
    public init() {
        
    }
    
    public func addTask(task: @escaping TaskType) throws {
        guard !shouldTerminate else {
            self.logger.error("Trying to add a task when we should terminate")
            throw Error.invalidStateForNewTasks
        }
        self.taskQueue.append(task)
    }
    
    public func start() async {
        Task {
            await withTaskGroup(of: Void.self) {
                group in
                
                do {
                    defer {
                        self.hasTerminated = true
                    }
                    
                    self.logger.info("Entering background task loop")
                    
                    while !shouldTerminate {
                        try await Task.sleep(nanoseconds: 5_000_000_000)
                        
                        let tasks = self.taskQueue
                        self.taskQueue = []
                        
                        for task in tasks {
                            group.addTask(priority: nil, operation: task)
                        }
                        
                        await group.waitForAll()
//                        for await _ in group {
//
//                        }
                    }
                    
                    // clean up last tasks ---
                    for task in self.taskQueue {
                        group.addTask(priority: nil, operation: task)
                    }
                    
                    await group.waitForAll()
                    // ---
                    
                    self.logger.info("Quitting background task loop")
                } catch {
                    fatalError("Background thread failed: \(String(describing: error))")
                }
            }
        }
    }
    
    public func waitAndShutdown() async throws {
        shouldTerminate = true
        while !self.hasTerminated {
            logger.info("Waiting for background tasks to finish...")
            try await Task.sleep(nanoseconds: 5_000_000_000)
        }
    }
}
