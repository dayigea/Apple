import SwiftData
import SwiftUI

/// 设置 Tab 的入口：卡片式分层 hub。
/// 顶部是宝宝头像 + 姓名 + 月龄；下方 3 张卡片分别进二级页。
struct SettingsView: View {

    @Bindable var baby: Baby

    @Query private var photos: [PhotoEntry]
    @Query private var milestones: [Milestone]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    headerCard
                    cards
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(spacing: 12) {
            SettingsAvatar(data: baby.avatarData, size: 110)
            VStack(spacing: 4) {
                Text(baby.name.isEmpty ? "宝宝" : baby.name)
                    .font(.title2)
                    .fontWeight(.bold)
                Text(ageText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var ageText: String {
        AgeCalculator.age(birthday: baby.birthday, at: .now).localized
    }

    // MARK: - Cards

    private var cards: some View {
        VStack(spacing: 12) {
            NavigationLink {
                BabyProfileView(baby: baby)
            } label: {
                SettingsCard(
                    icon: "person.crop.circle",
                    title: "宝宝资料",
                    subtitle: "姓名 · 生日 · 性别 · 头像",
                    tint: .accentColor
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                PhotoSourceView(baby: baby)
            } label: {
                SettingsCard(
                    icon: "photo.stack",
                    title: "宝宝照片",
                    subtitle: photoSubtitle,
                    tint: .blue
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                AboutView(photoCount: photos.count, milestoneCount: milestones.count)
            } label: {
                SettingsCard(
                    icon: "info.circle",
                    title: "关于",
                    subtitle: "数据 · 版本 · 清理",
                    tint: .orange
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var photoSubtitle: String {
        if photos.isEmpty {
            return "还没有导入照片"
        }
        return "\(photos.count) 张已导入"
    }
}

// MARK: - 通用卡片

struct SettingsCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(0.14))
                    .frame(width: 48, height: 48)
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - 头像

struct SettingsAvatar: View {
    let data: Data?
    var size: CGFloat = 96

    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle().fill(Color.accentColor.opacity(0.15))
                    Image(systemName: "figure.child.circle")
                        .resizable()
                        .scaledToFit()
                        .padding(size * 0.22)
                        .foregroundStyle(Color.accentColor.opacity(0.7))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(.white, lineWidth: 2))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
    }
}
