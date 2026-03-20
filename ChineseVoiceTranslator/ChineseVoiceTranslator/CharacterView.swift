import SwiftUI

struct CharacterView: View {
    @State private var query = ""
    @State private var result: CharacterLookupResult?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let api = APIClient()

    var body: some View {
        ZStack(alignment: .top) {
            Theme.warmBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    headerView
                        .ignoresSafeArea(edges: .top)

                    VStack(spacing: 20) {
                        searchCard
                            .padding(.horizontal, 16)
                            .padding(.top, 24)

                        if let result = result, !result.characters.isEmpty {
                            resultCard(result: result)
                                .padding(.horizontal, 16)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }

                        if let error = errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text(error)
                                    .font(.callout)
                                    .foregroundColor(.red)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.08))
                            .cornerRadius(12)
                            .padding(.horizontal, 16)
                        }

                        Spacer(minLength: 40)
                    }
                    .animation(.spring(response: 0.45, dampingFraction: 0.8), value: result == nil)
                    .animation(.spring(response: 0.45, dampingFraction: 0.8), value: errorMessage)
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.red, Theme.red.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Text("字")
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
                    Text("Look up stroke animations")
                        .font(.subheadline)
                        .foregroundColor(Color.white.opacity(0.75))
                }
                .padding(.trailing, 20)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
    }

    // MARK: - Search Card

    private var searchCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("English, Pinyin, or Chinese", systemImage: "magnifyingglass")
                .font(.headline)
                .foregroundColor(Theme.red)

            HStack(spacing: 10) {
                TextField("e.g.  hello  •  ni hao  •  你好", text: $query)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
                    .font(.callout)
                    .onSubmit { lookup() }
                    .submitLabel(.search)

                Button {
                    lookup()
                } label: {
                    if isLoading {
                        ProgressView()
                            .frame(width: 44, height: 44)
                    } else {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(query.trimmingCharacters(in: .whitespaces).isEmpty
                                             ? Color.gray.opacity(0.35) : Theme.red)
                    }
                }
                .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
            }

            Text("Works with any English word, pinyin (e.g. ni hao), or Chinese characters.")
                .font(.caption)
                .foregroundColor(Color.black.opacity(0.4))
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.07), radius: 8, x: 0, y: 3)
    }

    // MARK: - Result Card

    @ViewBuilder
    private func resultCard(result: CharacterLookupResult) -> some View {
        VStack(spacing: 0) {
            // Info header
            VStack(spacing: 8) {
                Text(result.characters)
                    .font(.system(size: 64, weight: .bold))
                    .foregroundColor(.black)

                HStack(spacing: 10) {
                    Text(result.pinyin)
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(Theme.red)
                    if !result.english.isEmpty {
                        Text("·")
                            .foregroundColor(Color.black.opacity(0.3))
                        Text(result.english)
                            .font(.title3)
                            .foregroundColor(Color.black.opacity(0.65))
                    }
                }
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 16)

            Divider()
                .padding(.horizontal, 16)

            // Stroke animation
            StrokeOrderView(word: result.characters)
                .frame(maxWidth: .infinity)
                .frame(height: 260)

            if !result.english.isEmpty {
                Divider()
                    .padding(.horizontal, 16)
                Text(result.english)
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(Color.black.opacity(0.65))
                    .padding(.vertical, 14)
            }
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
    }

    // MARK: - Actions

    func lookup() {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        result = nil
        api.lookupCharacter(trimmed) { res, err in
            DispatchQueue.main.async {
                isLoading = false
                if let err = err { errorMessage = err; return }
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                    result = res
                }
            }
        }
    }
}
