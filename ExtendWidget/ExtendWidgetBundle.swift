//
//  ExtendWidgetBundle.swift
//  ExtendWidget
//
//  Created by CAVAN MANNENBACH on 6/8/26.
//

import WidgetKit
import SwiftUI

@main
struct ExtendWidgetBundle: WidgetBundle {
    var body: some Widget {
        ExtendWidget()
        WaterWidget()
        ExtendWidgetControl()
        ExtendWidgetLiveActivity()
    }
}
