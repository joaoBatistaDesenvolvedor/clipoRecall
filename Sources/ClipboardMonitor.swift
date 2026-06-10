import AppKit

final class ClipboardMonitor {
    struct Entry {
        let content: String
        let contentType: String  // "text" | "image" | "file"
    }

    var onNewContent: ((Entry) -> Void)?

    private var changeCount: Int
    private var timer: Timer?

    init() { changeCount = NSPasteboard.general.changeCount }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.check() }
        }
    }

    func stop() { timer?.invalidate(); timer = nil }

    private func check() {
        let current = NSPasteboard.general.changeCount
        guard current != changeCount else { return }
        changeCount = current

        let pb = NSPasteboard.general

        // Files
        if let urls = pb.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL], !urls.isEmpty {
            let paths = urls.map(\.path).joined(separator: "\n")
            onNewContent?(Entry(content: paths, contentType: "file"))
            return
        }

        // Images
        let imgTypes: [NSPasteboard.PasteboardType] = [
            .tiff, .png,
            NSPasteboard.PasteboardType("public.jpeg"),
        ]
        for type in imgTypes {
            if let data = pb.data(forType: type),
               let b64 = compressedBase64(data) {
                onNewContent?(Entry(content: b64, contentType: "image"))
                return
            }
        }

        // Text
        if let text = pb.string(forType: .string),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            onNewContent?(Entry(content: text, contentType: "text"))
        }
    }

    private func compressedBase64(_ data: Data) -> String? {
        guard let src = NSImage(data: data) else { return nil }
        let size = src.size
        guard size.width > 0, size.height > 0 else { return nil }

        let maxDim: CGFloat = 600
        let scale = min(maxDim / size.width, maxDim / size.height, 1.0)
        let newSize = NSSize(
            width:  max(floor(size.width  * scale), 1),
            height: max(floor(size.height * scale), 1)
        )

        let thumb = NSImage(size: newSize, flipped: false) { rect in
            src.draw(in: rect, from: NSRect(origin: .zero, size: size),
                     operation: .copy, fraction: 1)
            return true
        }

        guard let tiff   = thumb.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let jpeg   = bitmap.representation(using: .jpeg,
                               properties: [.compressionFactor: 0.75])
        else { return nil }

        return jpeg.base64EncodedString()
    }
}
