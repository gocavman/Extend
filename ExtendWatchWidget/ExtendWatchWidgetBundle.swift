//
//  ExtendWatchWidgetBundle.swift
//  ExtendWatchWidget
//
//  Created by CAVAN MANNENBACH on 6/11/26.
//

import WidgetKit
import SwiftUI

@main
struct ExtendWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        PlanComplication()
        StepsComplication()
        WaterComplication()
    }
}
