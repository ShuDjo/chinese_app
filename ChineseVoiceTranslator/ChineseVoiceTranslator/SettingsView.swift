import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var lang: LanguageManager

    var body: some View {
        ZStack(alignment: .top) {
            Theme.warmBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    headerView
                        .ignoresSafeArea(edges: .top)

                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 12) {
                            Label(lang.s.settingsSubtitle, systemImage: "globe")
                                .font(.headline)
                                .foregroundColor(Theme.red)

                            ForEach(AppLanguage.allCases, id: \.self) { language in
                                Button {
                                    lang.language = language
                                } label: {
                                    HStack {
                                        Text(language.flag + "  " + language.displayName)
                                            .font(.callout)
                                            .foregroundColor(lang.language == language ? .white : .primary)
                                        Spacer()
                                        if lang.language == language {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(lang.language == language ? Theme.red : Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(10)
                                }
                            }
                        }
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.07), radius: 8, x: 0, y: 3)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                        Spacer(minLength: 40)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private var headerView: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.red, Theme.red.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Text("语")
                .font(.system(size: 110, weight: .black))
                .foregroundColor(Color.white.opacity(0.08))
                .offset(x: 60, y: 10)

            HStack {
                Text("☭")
                    .font(.system(size: 100))
                    .foregroundColor(.white)
                    .padding(.leading, 12)
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("XuéBàn")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    Text(lang.s.settingsSubtitle)
                        .font(.subheadline)
                        .foregroundColor(Color.white.opacity(0.75))
                }
                .padding(.trailing, 20)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
    }
}
