//
//  TimelineDataModels.swift
//  XBible
//

import Foundation

// MARK: - Timeline Section
struct TimelineSection: Codable, Identifiable {
    let id: String
    let image: String
    let description: String
    let descriptionEn: String
    let startYear: Int
    let endYear: Int
    let interval: Int
    let title: String
    let titleEn: String
    let sectionTitle: String
    let sectionTitleEn: String
    let subTitle: String
    let subTitleEn: String
    let color: String
    let events: [TimelineEvent]
}

/// A lightweight version of TimelineSection without the full events array.
struct ShallowTimelineSection: Codable, Identifiable {
    let id: String
    let image: String
    let description: String
    let startYear: Int
    let endYear: Int
    let title: String
    let color: String
}

// MARK: - Event Type Enum
enum EventType: String, Codable {
    case period
    case event
    case person
    case life
    case major
    case minor// <--- Add this case
}

// MARK: - Timeline Event
struct TimelineEvent: Codable, Identifiable {
    let id: Int
    let title: String
    let titleEn: String
    let approx: Bool?
    let image: String?
    let slug: String
    let start: Int
    let end: Int
    let row: Int
    let column: Int
    let isFixed: Bool?
    let type: EventType

    enum CodingKeys: String, CodingKey {
        case id, title, titleEn, approx, image, slug, start, end, row, column, isFixed, type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Required fields
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        titleEn = try container.decode(String.self, forKey: .titleEn)
        slug = try container.decode(String.self, forKey: .slug)
        start = try container.decode(Int.self, forKey: .start)
        end = try container.decode(Int.self, forKey: .end)
        row = try container.decode(Int.self, forKey: .row)
        
        // Handle EventType safely
        type = try container.decodeIfPresent(EventType.self, forKey: .type) ?? .event

        // Optional fields
        approx = try container.decodeIfPresent(Bool.self, forKey: .approx)
        image = try container.decodeIfPresent(String.self, forKey: .image)
        isFixed = try container.decodeIfPresent(Bool.self, forKey: .isFixed)
        
        // Default column to 0 if missing in text file to prevent decoding errors
        column = try container.decodeIfPresent(Int.self, forKey: .column) ?? 0
    }
}

// MARK: - Timeline Event Detail
struct TimelineEventDetail: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let article: String
    let period: String
    let slug: String
    let dates: String
    let related: [RelatedEvent]
    let images: [EventImage]
    let videos: [EventVideo]
    let scriptures: [String]
}

// MARK: - Supporting Types
struct RelatedEvent: Codable {
    let slug: String
    let title: String
}

struct EventImage: Codable {
    let caption: String
    let file: String
}

struct EventVideo: Codable {
    let title: String
    let caption: String
    let filename: String
}
