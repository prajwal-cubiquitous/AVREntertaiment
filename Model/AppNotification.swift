//
//  AppNotification.swift
//  AVREntertainment
//
//  Created by Auto on 1/1/25.
//

import Foundation

// MARK: - AnyCodable Helper
/// A type-erased wrapper for Codable values
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable value cannot be decoded")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: container.codingPath, debugDescription: "AnyCodable value cannot be encoded"))
        }
    }
}

// MARK: - AppNotification Model
struct AppNotification: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let body: String
    let date: Date
    let data: [String: AnyCodable]
    let projectId: String? // Store project ID for filtering
    
    init(id: String = UUID().uuidString, title: String, body: String, date: Date = Date(), data: [String: Any] = [:], projectId: String? = nil) {
        self.id = id
        self.title = title
        self.body = body
        self.date = date
        self.data = data.mapValues { AnyCodable($0) }
        self.projectId = projectId
    }
    
    // Custom Codable implementation
    enum CodingKeys: String, CodingKey {
        case id, title, body, date, data, projectId
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        body = try container.decode(String.self, forKey: .body)
        date = try container.decode(Date.self, forKey: .date)
        data = try container.decode([String: AnyCodable].self, forKey: .data)
        projectId = try container.decodeIfPresent(String.self, forKey: .projectId)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(body, forKey: .body)
        try container.encode(date, forKey: .date)
        try container.encode(data, forKey: .data)
        try container.encodeIfPresent(projectId, forKey: .projectId)
    }
    
    // Equatable conformance
    static func == (lhs: AppNotification, rhs: AppNotification) -> Bool {
        lhs.id == rhs.id
    }
}

