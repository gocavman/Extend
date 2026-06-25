////
////  MirroredWorkoutCoordinator.swift
////  Extend
////
////  iPhone-side coordinator for a *mirrored* `HKWorkoutSession`. When a
////  workout/timer/voice trainer is started on the iPhone, this calls
////  `HKHealthStore.startWatchApp(toHandle:)` to wake the watch app, which
////  immediately mirrors its primary session back via `startMirroringTo
////  CompanionDevice()`. The iPhone catches the mirror in
////  `workoutSessionMirroringStartHandler`, becomes the mirrored counterpart,
////  and receives live HR/calorie samples through `HKLiveWorkoutBuilder`
////  for free — no custom WatchConnectivity streaming required.
////
////  Phone → watch control (end, cancel, name handshake) goes through the
////  bidirectional `sendToRemoteWorkoutSession` Data channel using the shared
////  `MirroredSessionMessage` envelope. The watch replies with an `endAck`
////  carrying the HKWorkout UUID it persisted on the primary side; the
////  caller (WorkoutModule / VoiceTrainerModule / TimerModule) stamps that
////  UUID onto its `WorkoutLog` so the iPhone doesn't re-export the same
////  workout to Apple Health.
////

import Foundation
import HealthKit
import Observation
import WatchConnectivity

@MainActor
@Observable
public final class MirroredWorkoutCoordinator: NSObject {

    public static let shared = MirroredWorkoutCoordinator()

    // MARK: - Observable state

    /// True while a mirrored session is in flight on this device.
    public private(set) var isMirroring: Bool = false
    /// Live heart rate streamed from the watch via the mirrored builder.
    public private(set) var heartRate: Double = 0
    /// Live active energy in kcal streamed from the watch.
    public private(set) var activeEnergyKcal: Double = 0
    /// Start date of the active mirrored session (nil when idle).
    public private(set) var startDate: Date?

    // MARK: - Private

    private let store = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    /// Continuation resumed once the mirror handler fires with a session.
    /// `requestStart` awaits this so callers know whether the wrist side
    /// actually connected before returning success.
    private var startContinuation: CheckedContinuation<Bool, Never>?
    /// Continuation resumed once the watch sends back an `endAck` carrying
    /// the HKWorkout UUID, or the mirror disconnects (whichever first).
    private var endContinuation: CheckedContinuation<UUID?, Never>?
    /// Tracks whether the active session is being torn down by the caller
    /// (via `requestEnd` / `requestCancel`) so the disconnect callback
    /// doesn't mistake an intentional teardown for an error.
    private var pendingTeardown: Bool = false

    private override init() { super.init() }

    // MARK: - Setup

    /// Installs the mirror-start handler on `HKHealthStore`. Apple's docs are
    /// emphatic that this must be set "as soon as your app launches" so a
    /// reconnecting mirror (after a transient link drop mid-workout) can
    /// re-establish itself even before any SwiftUI body renders. Safe to
    /// call repeatedly — the handler is idempotent.
    public func registerMirrorHandler() {
        guard HKHealthStore.isHealthDataAvailable() else {
            MirrorDiagnostics.log("HealthKit not available — handler not registered")
            return
        }
        store.workoutSessionMirroringStartHandler = { [weak self] mirroredSession in
            // The system calls this from an arbitrary background queue —
            // hop to MainActor before touching the diagnostics buffer or
            // adopting the session.
            Task { @MainActor [weak self] in
                MirrorDiagnostics.log("mirror-start handler fired — adopting session")
                self?.adoptMirroredSession(mirroredSession)
            }
        }
        MirrorDiagnostics.log("handler registered on HKHealthStore")
    }

    /// Asks for the HK types the iPhone side needs to fully process a
    /// mirrored session. Without share access to workout type the wake
    /// call (`startWatchApp(toHandle:)`) is rejected silently; without
    /// read access to heart rate + active energy the mirrored builder
    /// still connects but never delivers samples to our delegate. Safe to
    /// call repeatedly — iOS won't re-prompt for already-decided types.
    private func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        let share: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKQuantityType(.activeEnergyBurned)
        ]
        let read: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned)
        ]
        do {
            try await store.requestAuthorization(toShare: share, read: read)
            return true
        } catch {
            MirrorDiagnostics.log("HK auth request failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Reachability

    /// True only when there's an active, paired watch with the app installed.
    /// Unlike `WCSession.isReachable`, this does NOT require the watch app to
    /// already be running — `startWatchApp(toHandle:)` will launch it.
    public var isWatchAvailable: Bool {
        guard WCSession.isSupported() else { return false }
        let session = WCSession.default
        return session.activationState == .activated
            && session.isPaired
            && session.isWatchAppInstalled
    }

    // MARK: - Start

    /// Requests a mirrored workout session from the wrist. Wakes the watch
    /// app via `startWatchApp(toHandle:)`, waits for the mirror to establish,
    /// then sends the session name across the remote data channel so the
    /// watch can show "Squats" instead of "Workout" in its passive HUD.
    /// Returns true when the wrist side connected and the iPhone is now
    /// receiving live samples; false on any error (watch unavailable, HK
    /// auth missing, mirror handshake timed out).
    public func requestStart(activityTypeRaw: UInt?, name: String) async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            MirrorDiagnostics.log("requestStart: HealthKit unavailable")
            return false
        }
        let wcState = WCSession.default
        MirrorDiagnostics.log("requestStart: name=\(name) activity=\(activityTypeRaw ?? 0) " +
              "wcSupported=\(WCSession.isSupported()) " +
              "activation=\(wcState.activationState.rawValue) " +
              "paired=\(wcState.isPaired) " +
              "installed=\(wcState.isWatchAppInstalled) " +
              "reachable=\(wcState.isReachable)")
        guard isWatchAvailable else {
            MirrorDiagnostics.log("requestStart: watch not available — aborting")
            return false
        }

        // If there's already an active mirrored session, refuse rather than
        // overlapping. Callers should `requestEnd` first.
        guard !isMirroring, session == nil else {
            MirrorDiagnostics.log("requestStart: already mirroring — aborting")
            return false
        }

        // Make sure the iOS-side HKHealthStore is authorized for the
        // workout + sample types this mirror needs. Without this,
        // `startWatchApp(toHandle:)` returns success but the watch handle
        // never fires; with it, the system prompts on first use and
        // remembers the choice afterwards.
        let authorized = await requestAuthorization()
        guard authorized else {
            MirrorDiagnostics.log("requestStart: HK authorization failed — aborting")
            return false
        }

        let config = HKWorkoutConfiguration()
        config.activityType = HKWorkoutActivityTypeHelper.hkType(from: activityTypeRaw)
        config.locationType = .indoor

        // Set the continuation BEFORE asking the watch to start so a fast
        // mirror callback (the system can fire it almost immediately) can't
        // race past our await point.
        let connected: Bool = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            startContinuation = cont
            Task {
                do {
                    MirrorDiagnostics.log("calling startWatchApp(toHandle:)…")
                    try await store.startWatchApp(toHandle: config)
                    MirrorDiagnostics.log("startWatchApp returned — waiting for mirror handler")
                } catch {
                    MirrorDiagnostics.log("startWatchApp failed: \(error.localizedDescription)")
                    await MainActor.run {
                        self.startContinuation?.resume(returning: false)
                        self.startContinuation = nil
                    }
                }
            }
            // Safety: if the watch never mirrors back within 15s, fall
            // through so the caller can move on (the wrist will display
            // the system "no workout app available" affordance instead).
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                if let pending = self.startContinuation {
                    MirrorDiagnostics.log("timed out waiting for mirror handler (15s)")
                    self.startContinuation = nil
                    pending.resume(returning: false)
                }
            }
        }

        guard connected, let session else {
            MirrorDiagnostics.log("requestStart: did not connect")
            return false
        }
        MirrorDiagnostics.log("mirror established — sending name handshake")
        // Seed the wrist HUD with a human-readable name once the channel
        // is live. Fire-and-forget — failure here just leaves the watch
        // showing the activity type's default label.
        let payload = MirroredSessionMessage.name(name, activityTypeRaw: activityTypeRaw)
        if let data = payload.encoded() {
            do {
                try await session.sendToRemoteWorkoutSession(data: data)
            } catch {
                print("⚠️ Mirrored workout: name handshake failed — \(error.localizedDescription)")
            }
        }
        return true
    }

    // MARK: - End / cancel

    /// Asks the watch to end its primary session and return the saved
    /// HKWorkout's UUID. Caller stamps the returned UUID onto its WorkoutLog
    /// so the iPhone-side export path skips re-exporting (otherwise we'd end
    /// up with two HKWorkouts for one user session). Returns nil if no
    /// mirror is active or the wrist failed to ack within the timeout.
    public func requestEnd() async -> UUID? {
        guard let session, isMirroring else { return nil }
        pendingTeardown = true
        // Set the continuation first so a fast endAck can't race past.
        let uuid: UUID? = await withCheckedContinuation { (cont: CheckedContinuation<UUID?, Never>) in
            endContinuation = cont
            Task {
                do {
                    try await session.sendToRemoteWorkoutSession(data: MirroredSessionMessage.end.encoded() ?? Data())
                } catch {
                    print("❌ Mirrored workout: end signal failed — \(error.localizedDescription)")
                    await MainActor.run {
                        self.endContinuation?.resume(returning: nil)
                        self.endContinuation = nil
                    }
                }
            }
            // Watch should ack within a few seconds; allow generous slack
            // for HKWorkoutBuilder.finishWorkout's async save.
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                if let pending = self.endContinuation {
                    self.endContinuation = nil
                    pending.resume(returning: nil)
                }
            }
        }
        // Defensive: if the disconnect callback didn't already clear us
        // (e.g. timeout path), tear down here so the next start can run.
        clearState()
        return uuid
    }

    /// Asks the watch to discard its primary session without saving. The
    /// wrist drops the HKWorkout, no log is sent back, and the iPhone is
    /// expected to drop whatever local UI was driving the session.
    public func requestCancel() async {
        guard let session, isMirroring else { return }
        pendingTeardown = true
        do {
            try await session.sendToRemoteWorkoutSession(data: MirroredSessionMessage.cancel.encoded() ?? Data())
        } catch {
            print("⚠️ Mirrored workout: cancel signal failed — \(error.localizedDescription)")
        }
        clearState()
    }

    // MARK: - Mirror lifecycle

    private func adoptMirroredSession(_ mirroredSession: HKWorkoutSession) {
        // A reconnect after a transient link drop will call this again with
        // a brand new session instance. Drop any stale references so the
        // delegate callbacks always go to the current one.
        session = mirroredSession
        let liveBuilder = mirroredSession.associatedWorkoutBuilder()
        builder = liveBuilder
        mirroredSession.delegate = self
        liveBuilder.delegate = self
        isMirroring = true
        startDate = mirroredSession.startDate ?? Date()
        heartRate = 0
        activeEnergyKcal = 0

        if let cont = startContinuation {
            startContinuation = nil
            cont.resume(returning: true)
        }
    }

    private func clearState() {
        session = nil
        builder = nil
        isMirroring = false
        heartRate = 0
        activeEnergyKcal = 0
        startDate = nil
        pendingTeardown = false
        if let cont = startContinuation {
            startContinuation = nil
            cont.resume(returning: false)
        }
        if let cont = endContinuation {
            endContinuation = nil
            cont.resume(returning: nil)
        }
    }
}

// MARK: - HKWorkoutSessionDelegate

extension MirroredWorkoutCoordinator: HKWorkoutSessionDelegate {
    nonisolated public func workoutSession(_ workoutSession: HKWorkoutSession,
                                            didChangeTo toState: HKWorkoutSessionState,
                                            from fromState: HKWorkoutSessionState,
                                            date: Date) {}

    nonisolated public func workoutSession(_ workoutSession: HKWorkoutSession,
                                            didFailWithError error: Error) {
        Task { @MainActor in
            print("❌ Mirrored session failed: \(error.localizedDescription)")
            self.clearState()
        }
    }

    nonisolated public func workoutSession(_ workoutSession: HKWorkoutSession,
                                            didDisconnectFromRemoteDeviceWithError error: (any Error)?) {
        Task { @MainActor in
            if let error, !self.pendingTeardown {
                print("⚠️ Mirrored session disconnected: \(error.localizedDescription)")
            }
            // If `requestEnd` is still waiting for an ack, deliver nil so
            // it can return rather than hang on the timeout.
            if let cont = self.endContinuation {
                self.endContinuation = nil
                cont.resume(returning: nil)
            }
            self.clearState()
        }
    }

    nonisolated public func workoutSession(_ workoutSession: HKWorkoutSession,
                                            didReceiveDataFromRemoteWorkoutSession data: [Data]) {
        // HealthKit batches incoming payloads when iOS is suspended — walk
        // the whole array in arrival order.
        Task { @MainActor in
            for blob in data {
                guard let message = MirroredSessionMessage.decode(blob) else { continue }
                self.handle(message)
            }
        }
    }

    private func handle(_ message: MirroredSessionMessage) {
        switch message {
        case .endAck(let uuidString):
            let uuid = uuidString.flatMap { UUID(uuidString: $0) }
            if let cont = endContinuation {
                endContinuation = nil
                cont.resume(returning: uuid)
            }
        case .name, .end, .cancel:
            // Phone never receives these — they're phone → watch only.
            break
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension MirroredWorkoutCoordinator: HKLiveWorkoutBuilderDelegate {
    nonisolated public func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated public func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                                            didCollectDataOf collectedTypes: Set<HKSampleType>) {
        Task { @MainActor in
            for type in collectedTypes {
                guard let qType = type as? HKQuantityType,
                      let stats = workoutBuilder.statistics(for: qType) else { continue }
                switch qType {
                case HKQuantityType(.heartRate):
                    let unit = HKUnit.count().unitDivided(by: .minute())
                    if let v = stats.mostRecentQuantity()?.doubleValue(for: unit) {
                        self.heartRate = v
                    }
                case HKQuantityType(.activeEnergyBurned):
                    if let v = stats.sumQuantity()?.doubleValue(for: .kilocalorie()) {
                        self.activeEnergyKcal = v
                    }
                default:
                    break
                }
            }
        }
    }
}
