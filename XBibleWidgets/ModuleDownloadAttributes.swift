//
//  ModuleDownloadAttributes.swift
//  X-Bible
//
//  Created by Zoe Brooklyn on 9/28/26.
//
//  NOTE: This file MUST be a member of both the X-Bible app target
//  and the XBibleWidgets extension target. In Xcode's File Inspector,
//  check both boxes under "Target Membership".
//

import Foundation
import ActivityKit

struct ModuleDownloadAttributes: ActivityAttributes {

    /// Dynamic state — changes as the download progresses.
    public struct ContentState: Codable, Hashable {
        /// 0.0 … 1.0
        var progress: Double
        /// "Preparing", "Downloading", "Extracting", "Done", "Failed", "Cancelled"
        var status: String
        /// Bytes received so far (0 if not reported by the engine).
        var downloadedBytes: Int64
        /// Total bytes expected (0 if not reported).
        var totalBytes: Int64

        init(
            progress: Double,
            status: String,
            downloadedBytes: Int64 = 0,
            totalBytes: Int64 = 0
        ) {
            self.progress = progress
            self.status = status
            self.downloadedBytes = downloadedBytes
            self.totalBytes = totalBytes
        }
    }

    /// Static attributes — do not change over the activity's lifetime.
    var moduleName: String
    var sourceName: String
}
