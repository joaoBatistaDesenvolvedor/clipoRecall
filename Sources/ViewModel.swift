import Foundation
import AppKit

final class ClipboardViewModel: ObservableObject {
    @Published var items: [ClipboardItem] = []
    @Published var searchText: String = ""
    @Published var selectedId: Int?
    @Published var backendOnline: Bool = true

    var pinnedItems: [ClipboardItem] { filtered.filter(\.pinned) }
    var recentItems: [ClipboardItem]  { filtered.filter { !$0.pinned } }
    var allVisible: [ClipboardItem]   { pinnedItems + recentItems }

    private var filtered: [ClipboardItem] {
        guard !searchText.isEmpty else { return items }
        return items.filter { $0.content.localizedCaseInsensitiveContains(searchText) }
    }

    // ── Load ──────────────────────────────────────────────────────────────────

    func load() {
        Task {
            let fetched = await APIClient.shared.fetchHistory()
            await MainActor.run {
                self.items = fetched
                if self.selectedId == nil || !self.items.contains(where: { $0.id == self.selectedId }) {
                    self.selectedId = self.allVisible.first?.id
                }
            }
        }
    }

    // ── Actions ───────────────────────────────────────────────────────────────

    func delete(_ id: Int) {
        Task {
            await APIClient.shared.deleteItem(id: id)
            await MainActor.run {
                self.items.removeAll { $0.id == id }
            }
        }
    }

    func togglePin(_ id: Int) {
        Task {
            guard let updated = await APIClient.shared.togglePin(id: id) else { return }
            await MainActor.run {
                if let idx = self.items.firstIndex(where: { $0.id == id }) {
                    self.items[idx] = updated
                }
                let pinned   = self.items.filter(\.pinned)
                let unpinned = self.items.filter { !$0.pinned }
                self.items = pinned + unpinned
            }
        }
    }

    func clearHistory() {
        Task {
            await APIClient.shared.clearHistory()
            await MainActor.run {
                self.items.removeAll { !$0.pinned }
            }
        }
    }

    // ── Keyboard navigation ───────────────────────────────────────────────────

    func selectNext() {
        let all = allVisible
        guard !all.isEmpty else { return }
        if let id = selectedId, let idx = all.firstIndex(where: { $0.id == id }) {
            selectedId = all[min(idx + 1, all.count - 1)].id
        } else {
            selectedId = all.first?.id
        }
    }

    func selectPrevious() {
        let all = allVisible
        guard !all.isEmpty else { return }
        if let id = selectedId, let idx = all.firstIndex(where: { $0.id == id }) {
            selectedId = all[max(idx - 1, 0)].id
        } else {
            selectedId = all.first?.id
        }
    }

    func selectedItem() -> ClipboardItem? {
        guard let id = selectedId else { return nil }
        return items.first { $0.id == id }
    }
}
