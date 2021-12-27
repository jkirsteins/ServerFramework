//
//  SpecializedMetricsFactory.swift
//  
//
//  Created by Janis Kirsteins on 27/12/2021.
//

import Metrics

/// Factory for metrics primitives which are tailored to the current service.
/// E.g. it might wrap an underlying metrics provider, and add dimensions for the environment
/// and service name.
public protocol SpecializedMetricsFactory : MetricsFactory
{
    func counter(for: String, extraDimensions: [(String, String)]?) -> Counter
}
