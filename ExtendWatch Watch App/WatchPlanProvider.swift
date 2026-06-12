////
////  WatchPlanProvider.swift
////  ExtendWatch
////
////  WidgetKit TimelineProvider for the Plan Ring complication.
////  Reads today's WidgetPlanSnapshot from the shared App Group and
////  schedules hourly refreshes (same pattern as the iOS widget).
////

import WidgetKit
import SwiftUI

// MARK: - Entry

struct WatchPlanEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetPlanSnapshot
}

// MARK: - Provider

struct WatchPlanProvider: TimelineProvider {

    func placeholder(in context: Context) -> WatchPlanEntry {
        WatchPlanEntry(
            date: Date(),
            snapshot: WidgetPlanSnapshot(
                planName: "My Plan",
                date: Date(),
                items: [
                    WidgetPlanItem(name: "Morning Run",  icon: "dumbbell.fill",                         isCompleted: true),
                    WidgetPlanItem(name: "Pull-ups",     icon: "figure.strengthtraining.traditional",   isCompleted: false),
                    WidgetPlanItem(name: "Breathing",    icon: "waveform",                              isCompleted: false),
                ],
                isRestDay: false
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchPlanEntry) -> Void) {
        completion(WatchPlanEntry(date: Date(), snapshot: readWidgetSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchPlanEntry>) -> Void) {
        let snapshot = readWidgetSnapshot()
        let now = Date()
        var entries: [WatchPlanEntry] = []
        for hour in 0..<12 {
            if let date = Calendar.current.date(byAdding: .hour, value: hour, to: now) {
                entries.append(WatchPlanEntry(date: date, snapshot: snapshot))
            }
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}
