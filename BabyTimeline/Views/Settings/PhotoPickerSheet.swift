import PhotosUI
import SwiftUI

/// `PHPickerViewController` 的 SwiftUI 包装。
///
/// 用户在 picker 里可以走 Albums → People（人物与宠物）→ 宝宝 → 全选，
/// 拿到一组 `assetIdentifier`，然后我们直接按这个列表落库——
/// 完全跳过自家的人脸识别，依赖 Apple 的人像聚类。
struct PhotoPickerSheet: UIViewControllerRepresentable {

    @Binding var isPresented: Bool

    /// 用户选好后回调拿到的 `PHAsset.localIdentifier` 列表。
    /// 用户点取消时收到空数组。
    let onPicked: ([String]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .any(of: [.images, .videos])
        config.selectionLimit = 0  // 不限制
        config.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPickerSheet

        init(_ parent: PhotoPickerSheet) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            let identifiers = results.compactMap { $0.assetIdentifier }
            parent.isPresented = false
            parent.onPicked(identifiers)
        }
    }
}
