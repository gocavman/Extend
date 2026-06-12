////
////  WatchComplicationBundle.swift
////  ExtendWatch
////
////  WidgetBundle that registers both Watch complications.
////  NOTE: This is NOT the @main entry point — ExtendWatchApp.swift is.
////  The Watch app target uses a separate "Widget Extension" target for
////  complications, but if using a combined Watch app + complication target
////  (watchOS 9+), this bundle is the widget entry point for the extension.
////

import WidgetKit
import SwiftUI

@main
struct WatchComplicationBundle: WidgetBundle {
    var body: some Widget {
        PlanComplication()
        StepsComplication()
    }
}
