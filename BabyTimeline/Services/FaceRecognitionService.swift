import CoreGraphics
import Foundation
import Vision

/// 人脸检测 + 「认人」匹配。
///
/// 原理：
/// 1. 用户在设置里选一张「女儿本人、清晰正脸」的参考照
/// 2. 我们用 `VNDetectFaceRectanglesRequest` 找到最大的那张人脸
/// 3. 把人脸 bbox 稍微外扩（带上头发、下巴一点环境），用
///    `VNGenerateImageFeaturePrintRequest` 在这个 ROI 上算一个特征指纹
/// 4. 把 `VNFeaturePrintObservation` 归档成 `Data`，存在 `Baby.referenceFacePrintData`
///
/// 导入每张候选照片时：
/// - 检测所有人脸
/// - 逐个算特征指纹，与参考指纹做 `computeDistance`
/// - 任何一张脸距离 ≤ 阈值就认为「含有女儿本人」，纳入时间线
///
/// 注意：`VNGenerateImageFeaturePrintRequest` 并非专门的人脸识别模型，精度不如
/// 专业 FaceNet。但对于同一个小朋友在相近时间段的照片，匹配效果通常够用，
/// 且无需任何额外的 Core ML 模型文件。
enum FaceRecognitionService {

    // MARK: - 人脸检测

    /// 检测照片里所有人脸 bbox（Vision 坐标系：原点左下，归一化 0–1）
    static func detectFaces(in cgImage: CGImage) async -> [VNFaceObservation] {
        await withCheckedContinuation { continuation in
            let request = VNDetectFaceRectanglesRequest { request, _ in
                let faces = (request.results as? [VNFaceObservation]) ?? []
                continuation.resume(returning: faces)
            }
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: [])
            }
        }
    }

    // MARK: - 参考指纹生成（「选女儿那张照片」）

    /// 给定一张含女儿的参考照，生成可归档的特征指纹。
    /// 如果照片里没检测到人脸，返回 nil。
    static func generateReferencePrint(from cgImage: CGImage) async -> Data? {
        let faces = await detectFaces(in: cgImage)
        guard let largest = faces.max(by: { a, b in
            boxArea(a.boundingBox) < boxArea(b.boundingBox)
        }) else {
            return nil
        }
        guard let observation = await generatePrint(
            cgImage: cgImage,
            faceBox: largest.boundingBox
        ) else {
            return nil
        }
        return archive(observation)
    }

    // MARK: - 候选照片匹配

    /// 判断一张照片里是否含有与参考指纹匹配的人脸。
    /// - Returns: (是否命中, 照片里总人脸数)
    static func matchResult(
        in cgImage: CGImage,
        reference: VNFeaturePrintObservation,
        threshold: Float
    ) async -> (matched: Bool, faceCount: Int) {
        let faces = await detectFaces(in: cgImage)
        if faces.isEmpty { return (false, 0) }

        for face in faces {
            guard let candidate = await generatePrint(
                cgImage: cgImage,
                faceBox: face.boundingBox
            ) else {
                continue
            }
            var distance: Float = 0
            do {
                try candidate.computeDistance(&distance, to: reference)
                if distance <= threshold {
                    return (true, faces.count)
                }
            } catch {
                continue
            }
        }
        return (false, faces.count)
    }

    // MARK: - 归档 / 反归档

    static func archive(_ observation: VNFeaturePrintObservation) -> Data? {
        try? NSKeyedArchiver.archivedData(
            withRootObject: observation,
            requiringSecureCoding: true
        )
    }

    static func unarchive(_ data: Data) -> VNFeaturePrintObservation? {
        try? NSKeyedUnarchiver.unarchivedObject(
            ofClass: VNFeaturePrintObservation.self,
            from: data
        )
    }

    // MARK: - 私有：在指定 ROI 上生成特征指纹

    private static func generatePrint(
        cgImage: CGImage,
        faceBox: CGRect
    ) async -> VNFeaturePrintObservation? {
        await withCheckedContinuation { continuation in
            let request = VNGenerateImageFeaturePrintRequest { request, _ in
                let obs = (request.results as? [VNFeaturePrintObservation])?.first
                continuation.resume(returning: obs)
            }
            // 把人脸框外扩 20%，带上一点头发和下巴，特征更稳
            request.regionOfInterest = expand(faceBox, by: 0.2)
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }

    // MARK: - 小工具

    private static func boxArea(_ box: CGRect) -> CGFloat {
        box.width * box.height
    }

    /// 在归一化坐标系里把一个矩形按比例外扩，并夹到 [0,1]。
    private static func expand(_ box: CGRect, by factor: CGFloat) -> CGRect {
        let dx = box.width * factor / 2
        let dy = box.height * factor / 2
        let minX = max(0, box.minX - dx)
        let minY = max(0, box.minY - dy)
        let maxX = min(1, box.maxX + dx)
        let maxY = min(1, box.maxY + dy)
        return CGRect(
            x: minX,
            y: minY,
            width: max(0, maxX - minX),
            height: max(0, maxY - minY)
        )
    }
}
