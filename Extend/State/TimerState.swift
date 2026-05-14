////
////  TimerState.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 5/14/26.
////

import Foundation
import Observation

@Observable
public final class TimerState {
    public static let shared = TimerState()

    @ObservationIgnored private let storageKey = "timer_configs"

    public var configs: [TimerConfig] = []

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
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    private func loadConfigs() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([TimerConfig].self, from: data) {
            configs = decoded
        }
    }
}
