import Photos
import UIKit

/// 渲染一张精美的分享卡片图片（用于微信/朋友圈/保存到相册）。
///
/// 卡片类型：
/// - **里程碑卡片**：标题 + 日期 + 年龄 + 绑定照片
/// - **成长数据卡片**：最新测量数据 + 对比增长
/// - **时光对比卡片**：两张照片并排 + 年龄对比
enum ShareCardRenderer {

    // MARK: - 里程碑卡片

    static func milestoneCard(
        milestone: Milestone,
        baby: Baby,
        photo: UIImage? = nil
    ) -> UIImage {
        let w: CGFloat = 1080
        let h: CGFloat = 1440
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))

        return renderer.image { ctx in
            // 背景渐变
            let colors = [
                UIColor.systemPink.withAlphaComponent(0.08).cgColor,
                UIColor.systemOrange.withAlphaComponent(0.05).cgColor,
                UIColor.white.cgColor,
            ]
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: [0, 0.4, 1]
            ) else { return }
            ctx.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: w / 2, y: 0),
                end: CGPoint(x: w / 2, y: h),
                options: []
            )

            var y: CGFloat = 60

            // 照片区域
            if let photo {
                let photoH: CGFloat = 800
                let photoRect = CGRect(x: 40, y: y, width: w - 80, height: photoH)
                let path = UIBezierPath(roundedRect: photoRect, cornerRadius: 24)
                ctx.cgContext.saveGState()
                path.addClip()
                photo.draw(in: photoRect.aspectFill(imageSize: photo.size))
                ctx.cgContext.restoreGState()
                y += photoH + 40
            } else {
                y += 200
            }

            // 标题
            let titleAttr = cardCentered(
                UIFont.systemFont(ofSize: 52, weight: .bold)
            )
            NSAttributedString(string: milestone.title, attributes: titleAttr)
                .draw(in: CGRect(x: 40, y: y, width: w - 80, height: 70))
            y += 80

            // 日期 + 年龄
            let df = DateFormatter()
            df.locale = Locale(identifier: "zh_CN")
            df.dateFormat = "yyyy 年 M 月 d 日"
            let age = AgeCalculator.age(birthday: baby.birthday, at: milestone.date)
            let info = "\(df.string(from: milestone.date))  ·  \(age.localized)"
            NSAttributedString(
                string: info,
                attributes: cardCentered(
                    UIFont.systemFont(ofSize: 30),
                    color: .secondaryLabel
                )
            ).draw(in: CGRect(x: 40, y: y, width: w - 80, height: 44))
            y += 56

            // 备注
            if let note = milestone.note, !note.isEmpty {
                NSAttributedString(
                    string: "「\(note)」",
                    attributes: cardCentered(
                        UIFont.systemFont(ofSize: 26),
                        color: .tertiaryLabel
                    )
                ).draw(with: CGRect(x: 60, y: y, width: w - 120, height: 120),
                       options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                       context: nil)
                y += 80
            }

            // 底部水印
            let watermark = "\(baby.name) 的成长记录"
            NSAttributedString(
                string: watermark,
                attributes: cardCentered(
                    UIFont.systemFont(ofSize: 22, weight: .light),
                    color: UIColor.tertiaryLabel
                )
            ).draw(in: CGRect(x: 40, y: h - 80, width: w - 80, height: 30))
        }
    }

    // MARK: - 成长数据卡片

    static func growthCard(
        baby: Baby,
        latest: GrowthRecord,
        previous: GrowthRecord?
    ) -> UIImage {
        let w: CGFloat = 1080
        let h: CGFloat = 720
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))

        return renderer.image { ctx in
            // 背景
            UIColor.systemBackground.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))

            let colors = [
                UIColor.systemTeal.withAlphaComponent(0.06).cgColor,
                UIColor.white.cgColor,
            ]
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: [0, 1]
            ) else { return }
            ctx.cgContext.drawLinearGradient(
                gradient,
                start: .zero,
                end: CGPoint(x: w, y: h),
                options: []
            )

            var y: CGFloat = 50

            // 标题
            let age = AgeCalculator.age(birthday: baby.birthday, at: latest.date)
            NSAttributedString(
                string: "\(baby.name)  \(age.localized)",
                attributes: cardCentered(UIFont.systemFont(ofSize: 40, weight: .bold))
            ).draw(in: CGRect(x: 40, y: y, width: w - 80, height: 56))
            y += 70

            let df = DateFormatter()
            df.locale = Locale(identifier: "zh_CN")
            df.dateFormat = "yyyy 年 M 月 d 日 测量"
            NSAttributedString(
                string: df.string(from: latest.date),
                attributes: cardCentered(
                    UIFont.systemFont(ofSize: 24),
                    color: .secondaryLabel
                )
            ).draw(in: CGRect(x: 40, y: y, width: w - 80, height: 36))
            y += 60

            // 数据卡
            let metrics: [(String, String, String?)] = [
                ("身高", latest.heightCM.map { String(format: "%.1f cm", $0) } ?? "—",
                 delta(latest.heightCM, previous?.heightCM, unit: "cm")),
                ("体重", latest.weightKG.map { String(format: "%.2f kg", $0) } ?? "—",
                 delta(latest.weightKG, previous?.weightKG, unit: "kg")),
                ("头围", latest.headCircumCM.map { String(format: "%.1f cm", $0) } ?? "—",
                 delta(latest.headCircumCM, previous?.headCircumCM, unit: "cm")),
            ]

            let cardW = (w - 120) / 3
            for (i, metric) in metrics.enumerated() {
                let x: CGFloat = 40 + CGFloat(i) * (cardW + 20)
                drawMetricCard(
                    label: metric.0,
                    value: metric.1,
                    delta: metric.2,
                    rect: CGRect(x: x, y: y, width: cardW, height: 220)
                )
            }

            // 水印
            NSAttributedString(
                string: "\(baby.name) 的成长记录",
                attributes: cardCentered(
                    UIFont.systemFont(ofSize: 20, weight: .light),
                    color: .tertiaryLabel
                )
            ).draw(in: CGRect(x: 40, y: h - 60, width: w - 80, height: 28))
        }
    }

    // MARK: - 时光对比卡片

    static func comparisonCard(
        baby: Baby,
        oldPhoto: UIImage,
        oldDate: Date,
        newPhoto: UIImage,
        newDate: Date,
        label: String
    ) -> UIImage {
        let w: CGFloat = 1080
        let h: CGFloat = 1080
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))

        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))

            var y: CGFloat = 40

            // 标题
            NSAttributedString(
                string: label,
                attributes: cardCentered(UIFont.systemFont(ofSize: 36, weight: .bold))
            ).draw(in: CGRect(x: 40, y: y, width: w - 80, height: 50))
            y += 64

            // 两张照片并排
            let photoW = (w - 100) / 2
            let photoH: CGFloat = 680

            let leftRect = CGRect(x: 30, y: y, width: photoW, height: photoH)
            let rightRect = CGRect(x: 30 + photoW + 40, y: y, width: photoW, height: photoH)

            drawRoundedPhoto(oldPhoto, in: leftRect, ctx: ctx.cgContext)
            drawRoundedPhoto(newPhoto, in: rightRect, ctx: ctx.cgContext)

            y += photoH + 16

            // 年龄标签
            let oldAge = AgeCalculator.age(birthday: baby.birthday, at: oldDate)
            let newAge = AgeCalculator.age(birthday: baby.birthday, at: newDate)

            let leftLabel = cardCentered(UIFont.systemFont(ofSize: 28), color: .secondaryLabel)
            let rightLabel = cardCentered(UIFont.systemFont(ofSize: 28), color: .secondaryLabel)

            NSAttributedString(string: oldAge.localized, attributes: leftLabel)
                .draw(in: CGRect(x: 30, y: y, width: photoW, height: 40))
            NSAttributedString(string: newAge.localized, attributes: rightLabel)
                .draw(in: CGRect(x: 30 + photoW + 40, y: y, width: photoW, height: 40))
            y += 44

            // 日期
            let df = DateFormatter()
            df.locale = Locale(identifier: "zh_CN")
            df.dateFormat = "yyyy/M/d"

            let smallLabel = cardCentered(UIFont.systemFont(ofSize: 22), color: .tertiaryLabel)
            NSAttributedString(string: df.string(from: oldDate), attributes: smallLabel)
                .draw(in: CGRect(x: 30, y: y, width: photoW, height: 30))
            NSAttributedString(string: df.string(from: newDate), attributes: smallLabel)
                .draw(in: CGRect(x: 30 + photoW + 40, y: y, width: photoW, height: 30))

            // 箭头
            let arrowX = 30 + photoW + 4
            NSAttributedString(
                string: "→",
                attributes: cardCentered(UIFont.systemFont(ofSize: 32), color: .systemPink)
            ).draw(in: CGRect(x: arrowX, y: photoH / 2 + 40, width: 32, height: 40))

            // 水印
            NSAttributedString(
                string: "\(baby.name) 的成长记录",
                attributes: cardCentered(
                    UIFont.systemFont(ofSize: 20, weight: .light),
                    color: .tertiaryLabel
                )
            ).draw(in: CGRect(x: 40, y: h - 50, width: w - 80, height: 28))
        }
    }

    // MARK: - 内部工具

    private static func cardCentered(
        _ font: UIFont,
        color: UIColor = .label
    ) -> [NSAttributedString.Key: Any] {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        return [.font: font, .foregroundColor: color, .paragraphStyle: style]
    }

    private static func drawRoundedPhoto(
        _ image: UIImage,
        in rect: CGRect,
        ctx: CGContext
    ) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 20)
        ctx.saveGState()
        path.addClip()
        image.draw(in: rect.aspectFill(imageSize: image.size))
        ctx.restoreGState()
    }

    private static func drawMetricCard(
        label: String,
        value: String,
        delta: String?,
        rect: CGRect
    ) {
        UIColor.systemGray6.setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: 16).fill()

        var y = rect.minY + 24

        NSAttributedString(
            string: label,
            attributes: cardCentered(UIFont.systemFont(ofSize: 22), color: .secondaryLabel)
        ).draw(in: CGRect(x: rect.minX, y: y, width: rect.width, height: 30))
        y += 44

        NSAttributedString(
            string: value,
            attributes: cardCentered(UIFont.systemFont(ofSize: 36, weight: .bold))
        ).draw(in: CGRect(x: rect.minX, y: y, width: rect.width, height: 50))
        y += 60

        if let delta {
            let deltaColor: UIColor = delta.hasPrefix("+") ? .systemGreen : .secondaryLabel
            NSAttributedString(
                string: delta,
                attributes: cardCentered(UIFont.systemFont(ofSize: 20), color: deltaColor)
            ).draw(in: CGRect(x: rect.minX, y: y, width: rect.width, height: 28))
        }
    }

    private static func delta(_ current: Double?, _ prev: Double?, unit: String) -> String? {
        guard let c = current, let p = prev else { return nil }
        let diff = c - p
        let sign = diff >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", diff)) \(unit)"
    }
}

// MARK: - CGRect helper (reuse)

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
