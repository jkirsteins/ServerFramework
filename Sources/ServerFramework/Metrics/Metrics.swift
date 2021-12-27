//
//  Metrics.swift
//  
//
//  Created by Janis Kirsteins on 27/12/2021.
//

import Metrics

/// Class for handling metrics of a given `Metric` enum.
public class Metrics<T> where T: Metric
{
    let factory: (T)->Counter
    
    public init(factory: @escaping (T)->Counter) {
        self.factory = factory
    }
    
    public convenience init(metricsFactory: SpecializedMetricsFactory) {
        self.init() {
            metricsFactory.counter(for: $0.name, extraDimensions: $0.extraDimensions)
        }
    }
    
    public func increment(metric: T) {
        factory(metric).increment()
    }
}
