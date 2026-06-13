////
////  WatchPlanDetailView.swift
////  ExtendWatch
////
////  The main Watch app view: shows a scrollable list of plan items for a
////  given day, with crown/swipe navigation to browse ±7 days.
////

import SwiftUI

struct WatchPlanDetailView: View {

    // Offset from today: 0 = today, -1 = yesterday, +1 = tomorrow, etc.
    @State private var dayOffset: Int = 0
    @State private var refreshToken: UUID = UUID()

    private let range = -7...7  // ±7 days

    // Snapshots keyed by day offset (populated from multi-day snapshot array).
    // refreshToken is read here so that changing it forces a re-evaluation.
    private var snapshots: [Int: WidgetPlanSnapshot] {
        _ = refreshToken
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var result: [Int: WidgetPlanSnapshot] = [:]
        for snap in readMultiDaySnapshots() {
            let days = cal.dateComponents([.day], from: today, to: cal.startOfDay(for: snap.date)).day ?? 0
            result[days] = snap
        }
        return result
    }

    private var currentSnapshot: WidgetPlanSnapshot? {
        snapshots[dayOffset]
    }

    private var dayLabel: String {
        switch dayOffset {
        case 0:  return "Today"
        case 1:  return "Tomorrow"
        case -1: return "Yesterday"
        default:
            let cal = Calendar.current
            guard let d = cal.date(byAdding: .day, value: dayOffset, to: Date()) else { return "" }
            let fmt = DateFormatter()
            fmt.dateFormat = "EEE, MMM d"
            return fmt.string(from: d)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Day navigation bar
                HStack {
                    Button {
                        if dayOffset > range.lowerBound { dayOffset -= 1 }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .disabled(dayOffset <= range.lowerBound)

                    Spacer()

                    VStack(spacing: 0) {
                        Text(dayLabel)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                        if let snap = currentSnapshot, let name = snap.planName {
                            Text(name)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    Button {
                        if dayOffset < range.upperBound { dayOffset += 1 }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .disabled(dayOffset >= range.upperBound)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)

                Divider()

                // Plan items list
                if let snap = currentSnapshot {
                    if snap.isRestDay || snap.items.isEmpty {
                        restDayView
                    } else {
                        planItemsList(snap.items)
                    }
                } else {
                    noPlanView
                }
            }
            .navigationBarHidden(true)
        }
        .onReceive(NotificationCenter.default.publisher(for: .watchPlanDataUpdated)) { _ in
            refreshToken = UUID()
        }
    }

    // MARK: - Sub-views

    private var restDayView: some View {
        VStack(spacing: 6) {
            Spacer()
            Image(systemName: "zzz")
                .font(.system(size: 28))
                .foregroundColor(.green)
            Text("Rest day")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var noPlanView: some View {
        VStack(spacing: 6) {
            Spacer()
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 24))
                .foregroundColor(.secondary)
            Text("No plan")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func planItemsList(_ items: [WidgetPlanItem]) -> some View {
        let completed = items.filter { $0.isCompleted }.count
        return ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                // Completion summary line
                HStack {
                    Text("\(completed)/\(items.count) done")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                    if completed == items.count {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.green)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.top, 4)

                ForEach(items, id: \.name) { item in
                    HStack(spacing: 6) {
                        Image(systemName: item.icon)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .frame(width: 16)
                        Text(item.name)
                            .font(.system(size: 12))
                            .lineLimit(2)
                            .foregroundColor(item.isCompleted ? .secondary : .primary)
                        Spacer()
                        if item.isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.vertical, 3)
                    .padding(.horizontal, 4)
                }
            }
        }
    }
}
