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
    let appearance: WatchComplicationUserSettings
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
            ),
            appearance: .default
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchPlanEntry) -> Void) {
        var snapshot = readWidgetSnapshot()
        // Fall back to preview data when nothing has been written from the iPhone yet
        if snapshot.items.isEmpty && !snapshot.isRestDay {
            snapshot = WidgetPlanSnapshot(
                planName: "My Plan",
                date: Date(),
                items: [
                    WidgetPlanItem(name: "Morning Run",  icon: "figure.run",                           isCompleted: true),
                    WidgetPlanItem(name: "Pull-ups",     icon: "figure.strengthtraining.traditional",  isCompleted: true),
                    WidgetPlanItem(name: "Stretching",   icon: "figure.flexibility",                   isCompleted: false),
                    WidgetPlanItem(name: "Core",         icon: "dumbbell.fill",                        isCompleted: false),
                    WidgetPlanItem(name: "Cool Down",    icon: "wind",                                 isCompleted: false),
                ],
                isRestDay: false
            )
        }
        completion(WatchPlanEntry(date: Date(), snapshot: snapshot, appearance: readWatchComplicationSettings()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchPlanEntry>) -> Void) {
        let snapshot = readWidgetSnapshot()
        let appearance = readWatchComplicationSettings()
        let now = Date()
        var entries: [WatchPlanEntry] = []
        for hour in 0..<12 {
            if let date = Calendar.current.date(byAdding: .hour, value: hour, to: now) {
                entries.append(WatchPlanEntry(date: date, snapshot: snapshot, appearance: appearance))
            }
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}
