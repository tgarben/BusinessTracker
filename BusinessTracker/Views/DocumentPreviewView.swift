import SwiftUI
import PDFKit
import UIKit

/// A generated PDF (invoice or estimate) to preview. `Identifiable` so it can
/// drive a `.sheet(item:)`.
struct PreviewDoc: Identifiable {
    let id = UUID()
    let url: URL
    let title: String
    /// Optional confirmation toast shown briefly when the preview opens
    /// (e.g. "Invoice Created"). Nil = no toast.
    var toast: String? = nil
    /// Called when the user actually *sends* the document from the share sheet
    /// (not merely saves/copies it). Used to auto-advance an estimate to "Sent".
    var onSent: (() -> Void)? = nil
}

/// Wraps a PDF URL for `.sheet(item:)`-driven sharing.
struct SharePDF: Identifiable {
    let id = UUID()
    let url: URL
    var onSent: (() -> Void)? = nil
}

/// `UIActivityViewController` bridge that reports the completion outcome —
/// unlike SwiftUI's `ShareLink`, which gives no callback. Lets callers tell a
/// real "send" (Mail, Messages, AirDrop…) apart from a "save" (Files, Copy…).
struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var onComplete: ((UIActivity.ActivityType?, Bool) -> Void)? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        vc.completionWithItemsHandler = { type, completed, _, _ in
            onComplete?(type, completed)
        }
        return vc
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

/// Classifies a share outcome. We only treat it as "sent" when the share
/// completed AND the chosen activity actually transmits the document — saving
/// to Files / Photos, copying, printing, etc. are explicitly NOT sending.
enum ShareOutcome {
    private static let saveToFiles = UIActivity.ActivityType("com.apple.DocumentManagerUICore.SaveToFiles")
    private static let nonSending: Set<UIActivity.ActivityType> = [
        .saveToCameraRoll, .copyToPasteboard, .print, .assignToContact,
        .addToReadingList, .markupAsPDF, .openInIBooks
    ]

    static func wasSent(activity: UIActivity.ActivityType?, completed: Bool) -> Bool {
        guard completed, let activity else { return false }
        return activity != saveToFiles && !nonSending.contains(activity)
    }
}

/// Full-page PDF preview with Share + Done. Shown right after creating an
/// invoice or estimate so the user can eyeball the finished document and send
/// it without an extra trip into the detail screen.
struct DocumentPreviewView: View {
    let doc: PreviewDoc
    @Environment(\.dismiss) private var dismiss
    @State private var showToast = false
    @State private var shareItem: SharePDF?

    var body: some View {
        NavigationStack {
            PDFKitView(url: doc.url)
                .ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .top) {
                    if let toast = doc.toast, showToast {
                        ToastBanner(text: toast)
                            .padding(.top, 10)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .navigationTitle(doc.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button { shareItem = SharePDF(url: doc.url, onSent: doc.onSent) } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel("Share")
                    }
                }
                .sheet(item: $shareItem) { item in
                    ActivityShareSheet(items: [item.url]) { activity, completed in
                        if ShareOutcome.wasSent(activity: activity, completed: completed) {
                            item.onSent?()
                        }
                    }
                }
                .task {
                    guard doc.toast != nil else { return }
                    withAnimation(.spring(duration: 0.45)) { showToast = true }
                    try? await Task.sleep(for: .seconds(1.9))
                    withAnimation(.easeOut(duration: 0.3)) { showToast = false }
                }
        }
    }
}

/// A small auto-dismissing confirmation pill.
private struct ToastBanner: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.green.opacity(0.25), lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 3)
    }
}

/// Minimal PDFKit wrapper for displaying a PDF at a file URL.
private struct PDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .systemGroupedBackground
        view.document = PDFDocument(url: url)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document?.documentURL != url {
            view.document = PDFDocument(url: url)
        }
    }
}
