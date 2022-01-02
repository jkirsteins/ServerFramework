//
//  BackgroundTaskScheduler.swift
//  
//
//  Created by Janis Kirsteins on 31/12/2021.
//

import Lifecycle
import Logging
import NIO
import NIOConcurrencyHelpers

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
    
    let elg: EventLoopGroup
    //    let interval: TimeAmount = .seconds(5)
    
    let taskQueueLock = Lock()
    var queue = CircularBuffer<EventLoopFuture<Void>>()
    
    public init(eventLoopGroup: EventLoopGroup) {
        self.elg = eventLoopGroup
    }
    
    public func addTask(task: @escaping TaskType) throws {
        guard !shouldTerminate else {
            self.logger.error("Trying to add a task when we should terminate")
            throw Error.invalidStateForNewTasks
        }
        
        let promise = elg.next().makePromise(of: Void.self)
        Task {
            await task()
            promise.succeed(Void())
            self.logger.debug("Task finished. Entering lock to remove from cleanup queue...")
            taskQueueLock.withLockVoid {
                if let ix = self.queue.firstIndex(where: { $0 == promise.futureResult }) {
                    self.queue.remove(at: ix)
                    self.logger.debug("Task removed from the cleanup queue.")
                } else {
                    self.logger.warning("Task not found in the cleanup queue.")
                }
            }
        }
        
        taskQueueLock.withLockVoid {
            self.queue.append(promise.futureResult)
        }
    }
    
    public func waitAndShutdown() async throws {
        shouldTerminate = true
        
        while true {
            var count: Int = 0
            taskQueueLock.withLockVoid {
                count = self.queue.count
            }
            
            guard count > 0 else {
                logger.info("All background tasks have finished.")
                break
            }
            
            logger.info("Waiting for background tasks to finish. \(count) remaining...")
            try await Task.sleep(nanoseconds: 5_000_000_000)
        }
    }
}
