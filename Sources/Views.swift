import SwiftUI
import AppKit

// ── Root ──────────────────────────────────────────────────────────────────────

struct ClipboardHistoryView: View {
    @EnvironmentObject var vm: ClipboardViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
            searchBar
            Divider().opacity(0.5)
            itemList
            Divider().opacity(0.5)
            footer
        }
        .frame(width: 440, height: 560)
        .onAppear { vm.load() }
    }

    // ── Header ────────────────────────────────────────────────────────────────

    var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)

            Text("Área de Transferência")
                .font(.system(size: 14, weight: .semibold))

            Spacer()

            Button { closePanel() } label: {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    // ── Search ────────────────────────────────────────────────────────────────

    var searchBar: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)

            TextField("Buscar…", text: $vm.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .onChange(of: vm.searchText) { _, _ in
                    vm.selectedId = vm.allVisible.first?.id
                }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(.quinary))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    // ── Item List ─────────────────────────────────────────────────────────────

    @ViewBuilder
    var itemList: some View {
        if vm.items.isEmpty {
            emptyState(icon: "doc.on.clipboard", title: "Sem itens", subtitle: "Copie algo para começar")
        } else if vm.allVisible.isEmpty {
            emptyState(icon: "magnifyingglass", title: "Sem resultados", subtitle: "Tente outra busca")
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 3) {
                        if !vm.pinnedItems.isEmpty {
                            SectionLabel("Fixados")
                            ForEach(vm.pinnedItems) { ClipCard(item: $0).id($0.id) }
                        }
                        if !vm.recentItems.isEmpty {
                            SectionLabel("Recentes")
                                .padding(.top, vm.pinnedItems.isEmpty ? 0 : 6)
                            ForEach(vm.recentItems) { ClipCard(item: $0).id($0.id) }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
                .onChange(of: vm.selectedId) { _, id in
                    if let id { proxy.scrollTo(id, anchor: .center) }
                }
            }
        }
    }

    // ── Footer ────────────────────────────────────────────────────────────────

    var footer: some View {
        HStack {
            Text("\(vm.items.count) \(vm.items.count == 1 ? "item" : "itens")")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Limpar Histórico", role: .destructive) {
                withAnimation { vm.clearHistory() }
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.red)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func closePanel() { AppDelegate.shared?.hidePanel() }

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 32)).foregroundStyle(.tertiary)
            Text(title).font(.headline).foregroundStyle(.secondary)
            Text(subtitle).font(.caption).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// ── Section Label ─────────────────────────────────────────────────────────────

struct SectionLabel: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.top, 4)
    }
}

// ── Clip Card ─────────────────────────────────────────────────────────────────

struct ClipCard: View {
    let item: ClipboardItem
    @EnvironmentObject var vm: ClipboardViewModel
    @State private var isHovered = false

    private var isSelected: Bool { vm.selectedId == item.id }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            contentPreview
            Spacer(minLength: 0)
            if isHovered || isSelected {
                actions
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(cardBackground)
        .contentShape(Rectangle())
        .onTapGesture { AppDelegate.shared?.performPaste(item: item) }
        .onHover { hovered in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovered
                if hovered { vm.selectedId = item.id }
            }
        }
    }

    // ── Content preview per type ──────────────────────────────────────────────

    @ViewBuilder
    private var contentPreview: some View {
        switch item.contentType {
        case "image":
            imagePreview
        case "file":
            filePreview
        default:
            textPreview
        }
    }

    private var textPreview: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.content)
                .lineLimit(2)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(relativeTime(item.createdAt))
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
    }

    private var imagePreview: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let data = Data(base64Encoded: item.content),
               let nsImg = NSImage(data: data) {
                Image(nsImage: nsImg)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: 130)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Label("Imagem", systemImage: "photo")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Text(relativeTime(item.createdAt))
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var filePreview: some View {
        let paths = item.content.split(separator: "\n").map(String.init)
        return VStack(alignment: .leading, spacing: 3) {
            ForEach(paths.prefix(3), id: \.self) { path in
                HStack(spacing: 6) {
                    Image(systemName: iconForFile(path))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(width: 14)
                    Text(URL(fileURLWithPath: path).lastPathComponent)
                        .font(.system(size: 13))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
            }
            if paths.count > 3 {
                Text("+ \(paths.count - 3) arquivo(s)")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            Text(relativeTime(item.createdAt))
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // ── Actions ───────────────────────────────────────────────────────────────

    private var actions: some View {
        HStack(spacing: 6) {
            iconButton(systemName: item.pinned ? "pin.fill" : "pin",
                       tint: item.pinned ? .yellow : .secondary) { vm.togglePin(item.id) }
            iconButton(systemName: "trash", tint: .secondary) { vm.delete(item.id) }
        }
    }

    // ── Background ────────────────────────────────────────────────────────────

    @ViewBuilder
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(isSelected ? Color.accentColor.opacity(0.13)
                             : isHovered ? Color.primary.opacity(0.05) : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.accentColor.opacity(0.3) : Color.clear,
                                  lineWidth: 1)
            )
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private func iconButton(systemName: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11))
                .foregroundStyle(tint)
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
    }

    private func iconForFile(_ path: String) -> String {
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        switch ext {
        case "png", "jpg", "jpeg", "gif", "webp", "heic": return "photo"
        case "pdf":                                         return "doc.richtext"
        case "mp4", "mov", "avi", "mkv":                   return "film"
        case "mp3", "m4a", "wav", "flac":                  return "music.note"
        case "zip", "rar", "7z", "tar", "gz":              return "archivebox"
        case "swift", "py", "js", "ts", "json", "html":   return "chevron.left.forwardslash.chevron.right"
        default:                                            return "doc"
        }
    }
}

// ── Relative time ─────────────────────────────────────────────────────────────

private func relativeTime(_ iso: String) -> String {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    var date = f.date(from: iso)
    if date == nil {
        f.formatOptions = [.withInternetDateTime]
        date = f.date(from: iso)
    }
    guard let date else { return "" }
    let diff = Int(Date().timeIntervalSince(date))
    if diff < 60  { return "agora" }
    if diff < 3600 { return "\(diff / 60)m" }
    if diff < 86400 { return "\(diff / 3600)h" }
    return "\(diff / 86400)d"
}
