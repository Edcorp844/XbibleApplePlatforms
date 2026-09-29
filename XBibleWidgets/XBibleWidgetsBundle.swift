//
//  XBibleWidgetsBundle.swift
//  XBibleWidgets
//
//  Created by Zoe Brooklyn on 9/28/26.
//
//  NOTE: Extension target only. This is the sole @main in the
//  widget extension module. The app target's @main lives in
//  X_BibleApp.swift.
//

import WidgetKit
import SwiftUI

@main
struct XBibleWidgetsBundle: WidgetBundle {
    var body: some Widget {
        ModuleDownloadLiveActivity()
    }
}
