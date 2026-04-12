import Photos
import SwiftUI

/// 根据 PHAsset.localIdentifier 异步加载并显示一张图片。
/// - 支持 thumbnail / fullSize 两种尺寸
/// - 读取失败会展示一个占位图（而不是崩溃）
struct AsyncPHAssetImage: View {

    enum Size {
        case thumbnail(CGFloat) // 点尺寸
        case fullSize
    }

    let localIdentifier: String
    let size: Size

    @State private var image: UIImage?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if isLoading {
                Color(.secondarySystemBackground)
                    .overlay(ProgressView())
            } else {
                Color(.secondarySystemBackground)
                    .overlay(
                        Image(systemName: "photo.badge.exclamationmark")
                            .foregroundStyle(.secondary)
                    )
            }
        }
        .task(id: localIdentifier) {
            await load()
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }

        guard let asset = PhotoLibraryService.asset(withLocalIdentifier: localIdentifier) else {
            image = nil
            return
        }

        switch size {
        case .thumbnail(let pt):
            image = await PhotoLibraryService.requestThumbnail(for: asset, pointSize: pt)
        case .fullSize:
            image = await PhotoLibraryService.requestFullImage(for: asset)
        }
    }
}
