////
////  TimerState.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 5/14/26.
////

import Foundation
import Observation

private let defaults = UserDefaults(suiteName: "group.com.cavanmannenbach.extend") ?? .standard

@Observable
public final class TimerState {
    public static let shared = TimerState()

    @ObservationIgnored private let storageKey = "timer_configs"

    public var configs: [TimerConfig] = []

    /// Whether to keep the screen on during active sessions. Defaults to true.
    /// Uses standard UserDefaults to match @AppStorage in SettingsModule.
    public var keepScreenOn: Bool {
        get { UserDefaults.standard.object(forKey: "keepScreenOnDuringSession") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "keepScreenOnDuringSession") }
    }

    /// Set by the dashboard to deep-link directly into a specific timer's active screen
    public var pendingLaunchID: UUID? = nil

    private init() {
        loadConfigs()
    }

    // MARK: - CRUD

    public func addConfig(_ config: TimerConfig) {
        configs.append(config)
        saveConfigs()
    }

    public func updateConfig(_ config: TimerConfig) {
        if let index = configs.firstIndex(where: { $0.id == config.id }) {
            configs[index] = config
            saveConfigs()
        }
    }

    public func removeConfig(id: UUID) {
        configs.removeAll { $0.id == id }
        saveConfigs()
    }

    public func cloneConfig(_ config: TimerConfig) {
        var cloned = config
        cloned = TimerConfig(
            id: UUID(),
            name: "\(config.name) Copy",
            notes: config.notes,
            type: config.type,
            direction: config.direction,
            duration: config.duration,
            restDuration: config.restDuration,
            rounds: config.rounds,
            warmupDuration: config.warmupDuration,
            cooldownDuration: config.cooldownDuration,
            ladderStep: config.ladderStep,
            ladderPeakRounds: config.ladderPeakRounds,
            isFavorite: false
        )
        configs.append(cloned)
        saveConfigs()
    }

    public func toggleFavorite(id: UUID) {
        if let index = configs.firstIndex(where: { $0.id == id }) {
            configs[index].isFavorite.toggle()
            saveConfigs()
        }
    }

    // MARK: - Computed

    public var favoriteConfigs: [TimerConfig] {
        configs.filter { $0.isFavorite }
    }

    public func reset() {
        configs = []
        saveConfigs()
    }

    // MARK: - Persistence

    private func saveConfigs() {
        if let encoded = try? JSONEncoder().encode(configs) {
            defaults.set(encoded, forKey: storageKey)
        }
    }

    private func loadConfigs() {
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([TimerConfig].self, from: data) {
            configs = decoded
        }
    }
}
