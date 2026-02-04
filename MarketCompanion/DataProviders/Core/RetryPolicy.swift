// RetryPolicy.swift
// MarketCompanion
//
// Exponential backoff with jitter for transient failures.

import Foundation

struct RetryPolicy: Sendable {
    let maxRetries: Int
    let baseDelaySeconds: Double
    let maxDelaySeconds: Double
    let jitterFactor: Double

    static let `default` = RetryPolicy(maxRetries: 3, baseDelaySeconds: 1.0, maxDelaySeconds: 30.0, jitterFactor: 0.25)
    static let aggressive = RetryPolicy(maxRetries: 5, baseDelaySeconds: 0.5, maxDelaySeconds: 60.0, jitterFactor: 0.3)
    static let none = RetryPolicy(maxRetries: 0, baseDelaySeconds: 0, maxDelaySeconds: 0, jitterFactor: 0)

    func execute<T>(operation: () async throws -> T) async throws -> T {
        var lastError: Error?

        for attempt in 0...maxRetries {
            do {
                return try await operation()
            } catch {
                lastError = error

                // Don't retry non-retryable errors
                if let mdError = error as? MarketDataError, !mdError.isRetryable {
                    throw error
                }

                // Don't retry on last attempt
                if attempt == maxRetries {
                    break
                }

                // Calculate delay with exponential backoff + jitter
                let exponentialDelay = baseDelaySeconds * pow(2.0, Double(attempt))
                let clampedDelay = min(exponentialDelay, maxDelaySeconds)
                let jitter = clampedDelay * jitterFactor * Double.random(in: -1...1)
                let finalDelay = max(0, clampedDelay + jitter)

                try await Task.sleep(nanoseconds: UInt64(finalDelay * 1_000_000_000))
            }
        }

        throw lastError ?? MarketDataError.providerUnavailable
    }
}
