////
////  WatchComplicationBundle.swift
////  ExtendWatch
////
////  WidgetBundle that registers all Watch complications.
////  NOTE: This is NOT the @main entry point — ExtendWatchApp.swift is.
////

import WidgetKit
import SwiftUI

@main
struct WatchComplicationBundle: WidgetBundle {
    var body: some Widget {
        PlanComplication()
        StepsOnlyComplication()
        DistanceOnlyComplication()
        StepsAndDistanceComplication()
        WaterComplication()
    }
}
