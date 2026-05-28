//
//  IosLiveActivitiesBundle.swift
//  IosLiveActivities
//
//  Created by lms-taravann on 27/5/26.
//

import WidgetKit
import SwiftUI

@main
struct IosLiveActivitiesBundle: WidgetBundle {
    var body: some Widget {
        IosLiveActivities()
        IosLiveActivitiesControl()
        TimerLiveActivityWidget()
    }
}
