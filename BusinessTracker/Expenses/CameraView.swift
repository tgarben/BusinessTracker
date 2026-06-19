import SwiftUI
import UIKit

struct CameraView: UIViewControllerRepresentable {
    /// Camera by default; pass `.photoLibrary` to pick (and optionally crop) from the library.
    var sourceType: UIImagePickerController.SourceType = .camera
    /// When true, shows the built-in square "Move and Scale" crop step (used for the profile photo).
    var allowsEditing: Bool = false
    let onCapture: (UIImage) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(allowsEditing: allowsEditing, onCapture: onCapture, onCancel: onCancel) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.allowsEditing = allowsEditing
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let allowsEditing: Bool
        let onCapture: (UIImage) -> Void
        let onCancel: () -> Void

        init(allowsEditing: Bool, onCapture: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.allowsEditing = allowsEditing
            self.onCapture = onCapture
            self.onCancel = onCancel
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            // Prefer the cropped result when editing is on.
            let image = (allowsEditing ? info[.editedImage] as? UIImage : nil) ?? info[.originalImage] as? UIImage
            if let image {
                onCapture(image)
            }
            // Do NOT call picker.dismiss(animated:) — doing so inside a fullScreenCover
            // that is itself inside a sheet propagates the dismiss upward and closes the
            // parent form. SwiftUI dismisses the fullScreenCover via the binding instead.
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}

struct ReceiptPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)
            }
            .background(Color.black)
            .navigationTitle("Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
