////
////  TimerConfig.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 5/14/26.
////

import Foundation

public enum TimerType: String, Codable, CaseIterable, Identifiable {
    case standard = "Standard"
    case round    = "Round"
    case tabata   = "Tabata"
    case emom     = "EMOM"
    case amrap    = "AMRAP"
    case ladder   = "Ladder"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .standard: return "timer"
        case .round:    return "arrow.2.circlepath"
        case .tabata:   return "bolt.fill"
        case .emom:     return "clock.fill"
        case .amrap:    return "infinity"
        case .ladder:   return "chart.bar.fill"
        }
    }

    public var description: String {
        switch self {
        case .standard: return "Simple count up or down timer"
        case .round:    return "Alternating work and rest intervals"
        case .tabata:   return "20s work / 10s rest × 8 rounds"
        case .emom:     return "Every minute on the minute"
        case .amrap:    return "As many rounds as possible"
        case .ladder:   return "Ascending then descending intervals"
        }
    }
}

public enum TimerDirection: String, Codable, CaseIterable, Identifiable {
    case countDown = "Count Down"
    case countUp   = "Count Up"

    public var id: String { rawValue }
}

public struct TimerConfig: Identifiable, Codable, Hashable {
    public let id: UUID
    public var name: String
    public var notes: String
    public var type: TimerType
    public var direction: TimerDirection
    public var duration: Int          // main / work duration in seconds
    public var restDuration: Int      // rest duration in seconds
    public var rounds: Int            // number of rounds
    public var warmupDuration: Int    // seconds
    public var cooldownDuration: Int  // seconds
    public var ladderStep: Int        // seconds per ladder step
    public var ladderPeakRounds: Int  // steps up before coming back down
    public var isFavorite: Bool

    public init(
        id: UUID = UUID(),
        name: String = "",
        notes: String = "",
        type: TimerType = .standard,
        direction: TimerDirection = .countDown,
        duration: Int = 300,
        restDuration: Int = 60,
        rounds: Int = 8,
        warmupDuration: Int = 0,
        cooldownDuration: Int = 0,
        ladderStep: Int = 10,
        ladderPeakRounds: Int = 5,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.type = type
        self.direction = direction
        self.duration = duration
        self.restDuration = restDuration
        self.rounds = rounds
        self.warmupDuration = warmupDuration
        self.cooldownDuration = cooldownDuration
        self.ladderStep = ladderStep
        self.ladderPeakRounds = ladderPeakRounds
        self.isFavorite = isFavorite
    }

    /// Returns a copy of this config with preset defaults applied for the given type.
    public func applying(type newType: TimerType) -> TimerConfig {
        var c = self
        c.type = newType
        switch newType {
        case .standard:
            c.duration = 300
            c.direction = .countDown
        case .round:
            c.duration = 45
            c.restDuration = 15
            c.rounds = 10
        case .tabata:
            c.duration = 20
            c.restDuration = 10
            c.rounds = 8
        case .emom:
            c.duration = 60
            c.restDuration = 0
            c.rounds = 10
        case .amrap:
            c.duration = 600
            c.direction = .countDown
        case .ladder:
            c.ladderStep = 10
            c.ladderPeakRounds = 5
            c.restDuration = 10
        }
        return c
    }

    /// Human-readable summary of key parameters.
    public var parameterSummary: String {
        switch type {
        case .standard:
            return "\(direction.rawValue) · \(formattedSeconds(duration))"
        case .round:
            return "\(rounds) rounds · \(formattedSeconds(duration)) work / \(formattedSeconds(restDuration)) rest"
        case .tabata:
            return "\(rounds) rounds · \(duration)s work / \(restDuration)s rest"
        case .emom:
            return "\(rounds) min · \(formattedSeconds(duration)) work"
        case .amrap:
            return "\(formattedSeconds(duration)) · track rounds"
        case .ladder:
            return "Peak \(ladderPeakRounds) · \(ladderStep)s step · \(formattedSeconds(restDuration)) rest"
        }
    }

    private func formattedSeconds(_ s: Int) -> String {
        if s >= 60 {
            let m = s / 60
            let sec = s % 60
            return sec == 0 ? "\(m)m" : "\(m)m \(sec)s"
        }
        return "\(s)s"
    }
}
