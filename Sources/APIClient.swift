import Foundation

// ── Model ─────────────────────────────────────────────────────────────────────

struct ClipboardItem: Codable, Identifiable, Sendable {
    let id: Int
    var content: String
    var contentType: String
    var createdAt: String
    var pinned: Bool

    enum CodingKeys: String, CodingKey {
        case id, content, pinned
        case contentType = "content_type"
        case createdAt = "created_at"
    }
}

// ── Client ─────────────────────────────────────────────────────────────────────

actor APIClient {
    static let shared = APIClient()

    private let base = URL(string: "http://localhost:8765")!
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()

    func isReachable() async -> Bool {
        guard let url = URL(string: "/health", relativeTo: base) else { return false }
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch { return false }
    }

    func fetchHistory(search: String = "") async -> [ClipboardItem] {
        var components = URLComponents(url: URL(string: "/history", relativeTo: base)!, resolvingAgainstBaseURL: true)!
        if !search.isEmpty {
            components.queryItems = [URLQueryItem(name: "search", value: search)]
        }
        guard let url = components.url else { return [] }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return try decoder.decode([ClipboardItem].self, from: data)
        } catch { return [] }
    }

    func addItem(content: String, contentType: String = "text") async {
        guard let url = URL(string: "/clipboard", relativeTo: base) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["content": content, "content_type": contentType]
        req.httpBody = try? JSONEncoder().encode(body)
        _ = try? await URLSession.shared.data(for: req)
    }

    func deleteItem(id: Int) async {
        guard let url = URL(string: "/clipboard/\(id)", relativeTo: base) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        _ = try? await URLSession.shared.data(for: req)
    }

    func togglePin(id: Int) async -> ClipboardItem? {
        guard let url = URL(string: "/clipboard/\(id)/pin", relativeTo: base) else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        guard let (data, _) = try? await URLSession.shared.data(for: req) else { return nil }
        return try? decoder.decode(ClipboardItem.self, from: data)
    }

    func clearHistory() async {
        guard let url = URL(string: "/history", relativeTo: base) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        _ = try? await URLSession.shared.data(for: req)
    }
}
