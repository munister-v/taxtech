import PhotosUI
import SwiftUI

/// Текст на трьох мовах для екранів, що не лежать у translations.json: італійська й німецька беруть переклад із translations.json, а без нього - англійську.
func Tx(_ uk: String, _ en: String, _ ru: String) -> String {
    switch Lang.current {
    case .uk: uk
    case .ru: ru
    default: Translator.extra(uk) ?? en
    }
}

/// Вигляд аватара без фото: пара кольорів, форма й нахил. Без вибору колір береться з ініціалів, тож у кожного свій.
enum AvatarStyle {
    static let key = "avatarStyle"

    struct Palette: Identifiable {
        let id: Int
        let a: Color
        let b: Color
        let ink: Color
    }

    static let palettes: [Palette] = [
        .init(id: 0, a: Color(red: 0.99, green: 0.86, blue: 0.58), b: Color(red: 0.78, green: 0.56, blue: 0.22), ink: Color(red: 0.14, green: 0.09, blue: 0.02)),
        .init(id: 1, a: Color(red: 0.95, green: 0.30, blue: 0.28), b: Color(red: 0.45, green: 0.03, blue: 0.14), ink: .white),
        .init(id: 2, a: Color(red: 0.98, green: 0.62, blue: 0.30), b: Color(red: 0.80, green: 0.22, blue: 0.20), ink: .white),
        .init(id: 3, a: Color(red: 0.36, green: 0.80, blue: 0.62), b: Color(red: 0.04, green: 0.34, blue: 0.30), ink: .white),
        .init(id: 4, a: Color(red: 0.42, green: 0.62, blue: 0.98), b: Color(red: 0.12, green: 0.18, blue: 0.52), ink: .white),
        .init(id: 5, a: Color(red: 0.70, green: 0.52, blue: 0.96), b: Color(red: 0.28, green: 0.14, blue: 0.52), ink: .white),
        .init(id: 6, a: Color(red: 0.98, green: 0.58, blue: 0.74), b: Color(red: 0.62, green: 0.14, blue: 0.40), ink: .white),
        .init(id: 7, a: Color(red: 0.62, green: 0.88, blue: 0.94), b: Color(red: 0.14, green: 0.44, blue: 0.62), ink: Color(red: 0.02, green: 0.12, blue: 0.18)),
        .init(id: 8, a: Color(red: 0.90, green: 0.86, blue: 0.76), b: Color(red: 0.56, green: 0.50, blue: 0.40), ink: Color(red: 0.10, green: 0.09, blue: 0.06)),
        .init(id: 9, a: Color(red: 0.34, green: 0.34, blue: 0.38), b: Color(red: 0.05, green: 0.05, blue: 0.06), ink: Color(red: 0.99, green: 0.86, blue: 0.58)),
        .init(id: 10, a: Color(red: 0.78, green: 0.90, blue: 0.40), b: Color(red: 0.30, green: 0.50, blue: 0.10), ink: Color(red: 0.06, green: 0.14, blue: 0.02)),
        .init(id: 11, a: Color(red: 0.99, green: 0.78, blue: 0.40), b: Color(red: 0.88, green: 0.36, blue: 0.20), ink: Color(red: 0.20, green: 0.06, blue: 0.02)),
    ]

    /// Стабільний вибір за ініціалами: хеш не змінюється між запусками, на відміну від `hashValue`.
    static func auto(for seed: String) -> Int {
        // за замовчуванням графіт із золотом, як усе в застосунку
        9
    }

    static func resolved(seed: String) -> Palette {
        let saved = UserDefaults.standard.object(forKey: key) as? Int
        return palettes[(saved.flatMap { palettes.indices.contains($0) ? $0 : nil }) ?? auto(for: seed)]
    }
}

/// Круглий аватар: фото, а без нього градієнт із м'якою формою й ініціалами.
struct AvatarView: View {
    let initials: String
    var size: CGFloat = 40
    var style: Int?
    @AppStorage(ProfilePhoto.revKey) private var rev = 0
    @AppStorage(AvatarStyle.key) private var saved = -1

    var body: some View {
        Group {
            if style == nil, let img = ProfilePhoto.load() {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                generated
            }
        }
        .id(rev)
        .frame(width: size, height: size)
        .clipShape(.circle)
        .overlay(Circle().strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
    }

    private var palette: AvatarStyle.Palette {
        if let style { return AvatarStyle.palettes[style % AvatarStyle.palettes.count] }
        return saved >= 0 && saved < AvatarStyle.palettes.count ? AvatarStyle.palettes[saved] : AvatarStyle.palettes[AvatarStyle.auto(for: initials)]
    }

    @ViewBuilder private var generated: some View {
        if palette.id == 9 { signature } else { patterned }
    }

    /// Вигляд за замовчуванням: темний медальйон, тонке золоте кільце й ініціали золотом - без візерунка під літерами.
    private var signature: some View {
        // как в Revolut и Monobank: ровный тёплый круг и инициалы, без колец и узора
        ZStack {
            LinearGradient(colors: [Color(red: 0.93, green: 0.82, blue: 0.62), Color(red: 0.76, green: 0.60, blue: 0.38)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Text(initials).font(Theme.ui(size * 0.38, .bold))
                .foregroundStyle(Color(red: 0.20, green: 0.14, blue: 0.06))
        }
    }

    private var patterned: some View {
        let p = palette
        return ZStack {
            LinearGradient(colors: [p.a, p.b], startPoint: .topLeading, endPoint: .bottomTrailing)
            Canvas { ctx, sz in
                var c = ctx
                let mid = CGPoint(x: sz.width / 2, y: sz.height / 2)
                Engraving.rosette(in: &c, center: mid, radius: sz.width * 0.62, curves: 9, lobes: 7,
                                  color: p.ink.opacity(0.5), width: max(0.35, sz.width * 0.006))
                Engraving.rings(in: &c, center: mid, from: sz.width * 0.1, to: sz.width * 0.34, count: 5,
                                color: p.ink.opacity(0.3), width: max(0.3, sz.width * 0.005))
            }
            Circle().fill(RadialGradient(colors: [.black.opacity(0.55), .clear], center: .center, startRadius: 0, endRadius: size * 0.34))
                .frame(width: size * 0.7)
            Text(initials).font(Theme.mono(size * 0.34, .bold))
                .foregroundStyle(p.ink)
        }
    }
}

/// Вибір аватара: велике превʼю, дванадцять стилів, фото з галереї й повернення до автоматичного.
struct AvatarPicker: View {
    @Environment(\.dismiss) private var dismiss
    let initials: String
    @State private var pick: PhotosPickerItem?
    @AppStorage(AvatarStyle.key) private var saved = -1
    @AppStorage(ProfilePhoto.revKey) private var rev = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 26) {
                    AvatarView(initials: initials, size: 132)
                        .shadow(color: .black.opacity(0.35), radius: 22, y: 12)
                        .padding(.top, 12)
                        .animation(.smooth, value: saved)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4), spacing: 14) {
                        ForEach(AvatarStyle.palettes) { p in
                            Button {
                                ProfilePhoto.remove()
                                saved = p.id
                            } label: {
                                AvatarView(initials: initials, size: 66, style: p.id)
                                    .padding(4)
                                    .overlay(Circle().strokeBorder(Theme.ink, lineWidth: ProfilePhoto.load() == nil && current == p.id ? 2 : 0))
                            }
                            .buttonStyle(PressScale())
                        }
                    }
                    VStack(spacing: 10) {
                        PhotosPicker(selection: $pick, matching: .images) {
                            Label(Tx("Фото з галереї", "Photo from library", "Фото из галереи"), systemImage: "photo")
                                .font(Theme.ui(style: .body, .semibold))
                                .frame(maxWidth: .infinity, minHeight: 50)
                                .background(Theme.surface, in: .capsule)
                                .overlay(Capsule().strokeBorder(Theme.line, lineWidth: Theme.hairline))
                                .foregroundStyle(Theme.ink)
                        }
                        Button(Tx("Підібрати автоматично", "Reset to automatic", "Подобрать автоматически")) {
                            ProfilePhoto.remove()
                            saved = -1
                        }
                        .font(Theme.ui(style: .subheadline)).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 24)
            }
            .screenBackground()
            .navigationTitle(Tx("Аватар", "Avatar", "Аватар"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L("Готово").s) { dismiss() } } }
            .onChange(of: pick) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) { _ = ProfilePhoto.save(data) }
                    pick = nil
                }
            }
            .sensoryFeedback(.selection, trigger: saved)
        }
        .presentationDetents([.large])
    }

    private var current: Int { saved >= 0 ? saved : AvatarStyle.auto(for: initials) }
}
