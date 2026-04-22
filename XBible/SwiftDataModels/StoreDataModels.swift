//
//  StoreDataModels.swift
//  XBible
//
//  Created by Zoe Brooklyn on 4/22/26.
//

struct ModuleDownloadDetails: Equatable {
    var progress: Double
    var status: String
    var downloadedBytes: Int64
    var totalBytes: Int64
}

enum InstallationStatus: Equatable {
    case idle
    case pending
    case installing(details: ModuleDownloadDetails)
    case installed
    case cancelled
}
