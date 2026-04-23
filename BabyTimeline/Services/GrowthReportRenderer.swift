import Photos
import SwiftData
import UIKit

/// 把宝宝的成长数据渲染成一份可分享的 PDF。
///
/// 页面结构：
/// 1. **封面** — 头像 + 姓名 + 当前年龄 + 记录时间跨度
/// 2. **成长数据** — 最新一次测量 + 历史记录表
/// 3. **里程碑** — 按时间排列的里程碑列表
/// 4. **照片精选** — 收藏照片 / 里程碑绑定照片的缩略图网格
///
/// 全部在后台线程用 `UIGraphicsPDFRenderer` 绘制，输出 `Data`。
enum GrowthReportRenderer {

    struct ReportData {
        let baby: Baby
        let photos: [PhotoEntry]
        let milestones: [Milestone]
        let growthRecords: [GrowthRecord]
    }

    static func render(_ data: ReportData) async -> Data {
        let pageWidth: CGFloat = 595   // A4
        let pageHeight: CGFloat = 842
        let margin: CGFloat = 40
        let contentWidth = pageWidth - margin * 2

        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        )

        let favoritePhotos = data.photos.filter { $0.isFavorite }
        let thumbnails = await loadThumbnails(
            for: Array(favoritePhotos.prefix(12)),
            size: CGSize(width: 300, height: 300)
        )

        let avatar: UIImage? = data.baby.avatarData.flatMap { UIImage(data: $0) }

        let pdfData = renderer.pdfData { ctx in
            // ---- 封面 ----
            ctx.beginPage()
            var y = drawCover(
                ctx: ctx,
                baby: data.baby,
                avatar: avatar,
                photoCount: data.photos.count,
                videoCount: data.photos.filter { $0.isVideo }.count,
                milestoneCount: data.milestones.count,
                pageWidth: pageWidth,
                margin: margin,
                contentWidth: contentWidth
            )

            // ---- 成长数据 ----
            if !data.growthRecords.isEmpty {
                y = drawGrowthSection(
                    ctx: ctx,
                    records: data.growthRecords,
                    baby: data.baby,
                    y: y,
                    pageWidth: pageWidth,
                    pageHeight: pageHeight,
                    margin: margin,
                    contentWidth: contentWidth
                )
            }

            // ---- 里程碑 ----
            if !data.milestones.isEmpty {
                y = drawMilestoneSection(
                    ctx: ctx,
                    milestones: data.milestones,
                    baby: data.baby,
                    y: y,
                    pageWidth: pageWidth,
                    pageHeight: pageHeight,
                    margin: margin,
                    contentWidth: contentWidth
                )
            }

            // ---- 照片精选 ----
            if !thumbnails.isEmpty {
                drawPhotoGrid(
                    ctx: ctx,
                    thumbnails: thumbnails,
                    y: y,
                    pageWidth: pageWidth,
                    pageHeight: pageHeight,
                    margin: margin,
                    contentWidth: contentWidth
                )
            }
        }

        return pdfData
    }

    // MARK: - 封面

    @discardableResult
    private static func drawCover(
        ctx: UIGraphicsPDFRendererContext,
        baby: Baby,
        avatar: UIImage?,
        photoCount: Int,
        videoCount: Int,
        milestoneCount: Int,
        pageWidth: CGFloat,
        margin: CGFloat,
        contentWidth: CGFloat
    ) -> CGFloat {
        var y: CGFloat = 80

        // 头像
        let avatarSize: CGFloat = 100
        let avatarX = (pageWidth - avatarSize) / 2
        if let avatar {
            let rect = CGRect(x: avatarX, y: y, width: avatarSize, height: avatarSize)
            let path = UIBezierPath(ovalIn: rect)
            ctx.cgContext.saveGState()
            path.addClip()
            avatar.draw(in: rect)
            ctx.cgContext.restoreGState()
        } else {
            let rect = CGRect(x: avatarX, y: y, width: avatarSize, height: avatarSize)
            UIColor.systemGray5.setFill()
            UIBezierPath(ovalIn: rect).fill()
        }
        y += avatarSize + 20

        // 名字
        let nameAttr = centered(.systemFont(ofSize: 28, weight: .bold))
        let nameStr = NSAttributedString(string: "\(baby.name) 的成长报告", attributes: nameAttr)
        let nameRect = CGRect(x: margin, y: y, width: contentWidth, height: 40)
        nameStr.draw(in: nameRect)
        y += 44

        // 当前年龄
        let age = AgeCalculator.age(birthday: baby.birthday, at: .now)
        let ageStr = NSAttributedString(
            string: "当前年龄：\(age.localized)",
            attributes: centered(.systemFont(ofSize: 16), color: .secondaryLabel)
        )
        ageStr.draw(in: CGRect(x: margin, y: y, width: contentWidth, height: 24))
        y += 28

        // 生日
        let df = DateFormatter()
        df.locale = Locale(identifier: "zh_CN")
        df.dateFormat = "yyyy 年 M 月 d 日"
        let bdStr = NSAttributedString(
            string: "生日：\(df.string(from: baby.birthday))",
            attributes: centered(.systemFont(ofSize: 14), color: .tertiaryLabel)
        )
        bdStr.draw(in: CGRect(x: margin, y: y, width: contentWidth, height: 20))
        y += 24

        let reportDateStr = NSAttributedString(
            string: "报告生成于 \(df.string(from: .now))",
            attributes: centered(.systemFont(ofSize: 14), color: .tertiaryLabel)
        )
        reportDateStr.draw(in: CGRect(x: margin, y: y, width: contentWidth, height: 20))
        y += 40

        // 分隔线
        drawDivider(at: y, margin: margin, contentWidth: contentWidth)
        y += 20

        // 统计概览
        var statsText = "共记录了 \(photoCount) 张照片"
        if videoCount > 0 {
            statsText += "、\(videoCount) 段视频"
        }
        statsText += "、\(milestoneCount) 个里程碑"
        let statsStr = NSAttributedString(
            string: statsText,
            attributes: centered(.systemFont(ofSize: 15), color: .label)
        )
        statsStr.draw(in: CGRect(x: margin, y: y, width: contentWidth, height: 22))
        y += 40

        return y
    }

    // MARK: - 成长数据

    @discardableResult
    private static func drawGrowthSection(
        ctx: UIGraphicsPDFRendererContext,
        records: [GrowthRecord],
        baby: Baby,
        y startY: CGFloat,
        pageWidth: CGFloat,
        pageHeight: CGFloat,
        margin: CGFloat,
        contentWidth: CGFloat
    ) -> CGFloat {
        var y = startY

        y = ensureSpace(ctx: ctx, y: y, needed: 120, pageHeight: pageHeight,
                        pageWidth: pageWidth, margin: margin)

        // 标题
        y = drawSectionTitle("成长数据", at: y, margin: margin, contentWidth: contentWidth)

        let sorted = records.sorted { $0.date < $1.date }
        let df = DateFormatter()
        df.locale = Locale(identifier: "zh_CN")
        df.dateFormat = "yyyy/M/d"

        // 表头
        let headerFont = UIFont.systemFont(ofSize: 11, weight: .semibold)
        let headerColor = UIColor.secondaryLabel
        let cols: [(String, CGFloat)] = [
            ("日期", margin),
            ("年龄", margin + 90),
            ("身高(cm)", margin + 180),
            ("体重(kg)", margin + 270),
            ("头围(cm)", margin + 360),
        ]
        for (text, x) in cols {
            NSAttributedString(string: text, attributes: [
                .font: headerFont, .foregroundColor: headerColor
            ]).draw(at: CGPoint(x: x, y: y))
        }
        y += 20

        drawDivider(at: y, margin: margin, contentWidth: contentWidth, thin: true)
        y += 6

        // 数据行
        let rowFont = UIFont.systemFont(ofSize: 11)
        for record in sorted {
            y = ensureSpace(ctx: ctx, y: y, needed: 22, pageHeight: pageHeight,
                            pageWidth: pageWidth, margin: margin)

            let age = AgeCalculator.age(birthday: baby.birthday, at: record.date)
            let values: [String] = [
                df.string(from: record.date),
                age.localized,
                record.heightCM.map { String(format: "%.1f", $0) } ?? "—",
                record.weightKG.map { String(format: "%.2f", $0) } ?? "—",
                record.headCircumCM.map { String(format: "%.1f", $0) } ?? "—",
            ]
            for (i, val) in values.enumerated() {
                NSAttributedString(string: val, attributes: [
                    .font: rowFont, .foregroundColor: UIColor.label
                ]).draw(at: CGPoint(x: cols[i].1, y: y))
            }
            y += 20
        }
        y += 20
        return y
    }

    // MARK: - 里程碑

    @discardableResult
    private static func drawMilestoneSection(
        ctx: UIGraphicsPDFRendererContext,
        milestones: [Milestone],
        baby: Baby,
        y startY: CGFloat,
        pageWidth: CGFloat,
        pageHeight: CGFloat,
        margin: CGFloat,
        contentWidth: CGFloat
    ) -> CGFloat {
        var y = startY

        y = ensureSpace(ctx: ctx, y: y, needed: 80, pageHeight: pageHeight,
                        pageWidth: pageWidth, margin: margin)

        y = drawSectionTitle("成长里程碑", at: y, margin: margin, contentWidth: contentWidth)

        let sorted = milestones.sorted { $0.date < $1.date }
        let df = DateFormatter()
        df.locale = Locale(identifier: "zh_CN")
        df.dateFormat = "yyyy/M/d"

        let titleFont = UIFont.systemFont(ofSize: 13, weight: .medium)
        let detailFont = UIFont.systemFont(ofSize: 11)
        let noteFont = UIFont.systemFont(ofSize: 10)

        for milestone in sorted {
            let needed: CGFloat = milestone.note != nil ? 50 : 28
            y = ensureSpace(ctx: ctx, y: y, needed: needed, pageHeight: pageHeight,
                            pageWidth: pageWidth, margin: margin)

            let age = AgeCalculator.age(birthday: baby.birthday, at: milestone.date)
            let dot = "● "
            let line = "\(dot)\(milestone.title)"
            NSAttributedString(string: line, attributes: [
                .font: titleFont, .foregroundColor: UIColor.label
            ]).draw(at: CGPoint(x: margin, y: y))

            let dateAge = "\(df.string(from: milestone.date))  \(age.localized)"
            NSAttributedString(string: dateAge, attributes: [
                .font: detailFont, .foregroundColor: UIColor.secondaryLabel
            ]).draw(at: CGPoint(x: margin + 300, y: y + 1))
            y += 20

            if let note = milestone.note, !note.isEmpty {
                let noteStr = NSAttributedString(string: note, attributes: [
                    .font: noteFont, .foregroundColor: UIColor.tertiaryLabel
                ])
                let noteRect = CGRect(x: margin + 16, y: y, width: contentWidth - 16, height: 30)
                noteStr.draw(with: noteRect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                             context: nil)
                y += 22
            }
        }
        y += 20
        return y
    }

    // MARK: - 照片精选

    @discardableResult
    private static func drawPhotoGrid(
        ctx: UIGraphicsPDFRendererContext,
        thumbnails: [UIImage],
        y startY: CGFloat,
        pageWidth: CGFloat,
        pageHeight: CGFloat,
        margin: CGFloat,
        contentWidth: CGFloat
    ) -> CGFloat {
        var y = startY

        y = ensureSpace(ctx: ctx, y: y, needed: 180, pageHeight: pageHeight,
                        pageWidth: pageWidth, margin: margin)

        y = drawSectionTitle("收藏照片", at: y, margin: margin, contentWidth: contentWidth)

        let cols = 4
        let spacing: CGFloat = 8
        let cellSize = (contentWidth - spacing * CGFloat(cols - 1)) / CGFloat(cols)

        for (i, img) in thumbnails.enumerated() {
            let col = i % cols
            let row = i / cols

            if col == 0 && row > 0 {
                y = ensureSpace(ctx: ctx, y: y, needed: cellSize + spacing,
                                pageHeight: pageHeight, pageWidth: pageWidth, margin: margin)
            }

            let x = margin + CGFloat(col) * (cellSize + spacing)
            let cellY = y + CGFloat(row) * (cellSize + spacing)

            let rect = CGRect(x: x, y: cellY, width: cellSize, height: cellSize)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: 8)
            ctx.cgContext.saveGState()
            path.addClip()
            img.draw(in: rect.aspectFill(imageSize: img.size))
            ctx.cgContext.restoreGState()
        }

        let totalRows = (thumbnails.count + cols - 1) / cols
        y += CGFloat(totalRows) * (cellSize + spacing) + 20
        return y
    }

    // MARK: - 工具

    private static func drawSectionTitle(
        _ title: String,
        at y: CGFloat,
        margin: CGFloat,
        contentWidth: CGFloat
    ) -> CGFloat {
        drawDivider(at: y, margin: margin, contentWidth: contentWidth)
        var y = y + 12
        let attr = NSAttributedString(string: title, attributes: [
            .font: UIFont.systemFont(ofSize: 18, weight: .bold),
            .foregroundColor: UIColor.label,
        ])
        attr.draw(at: CGPoint(x: margin, y: y))
        y += 30
        return y
    }

    private static func drawDivider(
        at y: CGFloat,
        margin: CGFloat,
        contentWidth: CGFloat,
        thin: Bool = false
    ) {
        UIColor.separator.setStroke()
        let path = UIBezierPath()
        path.move(to: CGPoint(x: margin, y: y))
        path.addLine(to: CGPoint(x: margin + contentWidth, y: y))
        path.lineWidth = thin ? 0.5 : 1
        path.stroke()
    }

    private static func ensureSpace(
        ctx: UIGraphicsPDFRendererContext,
        y: CGFloat,
        needed: CGFloat,
        pageHeight: CGFloat,
        pageWidth: CGFloat,
        margin: CGFloat
    ) -> CGFloat {
        if y + needed > pageHeight - margin {
            ctx.beginPage()
            return margin
        }
        return y
    }

    private static func centered(
        _ font: UIFont,
        color: UIColor = .label
    ) -> [NSAttributedString.Key: Any] {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        return [.font: font, .foregroundColor: color, .paragraphStyle: style]
    }

    private static func loadThumbnails(
        for entries: [PhotoEntry],
        size: CGSize
    ) async -> [UIImage] {
        var result: [UIImage] = []
        for entry in entries {
            guard let asset = PHAsset.fetchAssets(
                withLocalIdentifiers: [entry.assetLocalId], options: nil
            ).firstObject else { continue }

            if let img = await PhotoLibraryService.requestThumbnail(
                for: asset, pointSize: size.width / 3
            ) {
                result.append(img)
            }
        }
        return result
    }
}

// MARK: - CGRect helper

private extension CGRect {
    func aspectFill(imageSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return self }
        let scale = max(width / imageSize.width, height / imageSize.height)
        let newW = imageSize.width * scale
        let newH = imageSize.height * scale
        return CGRect(
            x: midX - newW / 2,
            y: midY - newH / 2,
            width: newW,
            height: newH
        )
    }
}
