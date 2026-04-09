import Foundation

struct GeminiResponse: Codable, Sendable {
    let candidates: [GeminiCandidate]
}

struct GeminiCandidate: Codable, Sendable {
    let content: GeminiContent
}

struct GeminiContent: Codable, Sendable {
    let parts: [GeminiPart]
}

struct GeminiPart: Codable, Sendable {
    let text: String
}

