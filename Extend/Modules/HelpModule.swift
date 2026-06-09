////
////  HelpModule.swift
////  Extend
////

import SwiftUI
import Observation

// MARK: - Models

struct HelpSection: Codable {
    var heading: String
    var body: String
}

struct HelpArticle: Codable, Identifiable {
    var id: String
    var category: String
    var title: String
    var icon: String
    var summary: String
    var keywords: [String]
    var sections: [HelpSection]
}

// MARK: - Store

@Observable
final class HelpStore {
    private(set) var articles: [HelpArticle] = []
    var searchText: String = ""

    init() {
        load()
    }

    private func load() {
        guard let url = Bundle.main.url(forResource: "help", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([HelpArticle].self, from: data)
        else { return }
        articles = decoded
    }

    var filtered: [HelpArticle] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return articles }
        return articles.filter { article in
            article.title.lowercased().contains(trimmed) ||
            article.summary.lowercased().contains(trimmed) ||
            article.keywords.contains(where: { $0.lowercased().contains(trimmed) }) ||
            article.sections.contains(where: {
                $0.heading.lowercased().contains(trimmed) ||
                $0.body.lowercased().contains(trimmed)
            })
        }
    }

    var groupedFiltered: [(category: String, articles: [HelpArticle])] {
        let categoryOrder = ["General", "Modules", "Settings"]
        let grouped = Dictionary(grouping: filtered, by: { $0.category })
        return categoryOrder.compactMap { cat in
            guard let items = grouped[cat], !items.isEmpty else { return nil }
            return (category: cat, articles: items)
        }
    }
}

// MARK: - Help View

struct HelpView: View {
    @State private var store = HelpStore()

    var body: some View {
        VStack(spacing: 0) {
            SearchField(text: $store.searchText, placeholder: "Search help topics...")
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)
                .background(Color(UIColor.systemBackground))

            List {
                if store.groupedFiltered.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 28, weight: .light))
                                .foregroundColor(.secondary)
                            Text("No results for \"\(store.searchText)\"")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 40)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(store.groupedFiltered, id: \.category) { group in
                        Section(group.category) {
                            ForEach(group.articles) { article in
                                NavigationLink(destination: HelpDetailView(article: article)) {
                                    HelpArticleRow(article: article)
                                }
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(UIColor.systemBackground))
        }
        .background(Color(UIColor.systemBackground))
        .navigationTitle("Help")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Article Row

private struct HelpArticleRow: View {
    let article: HelpArticle

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: article.icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.accentColor)
                .frame(width: 28, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(article.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Text(article.summary)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Detail View

struct HelpDetailView: View {
    let article: HelpArticle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ForEach(Array(article.sections.enumerated()), id: \.offset) { _, section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.heading)
                            .font(.headline)
                            .foregroundColor(.primary)
                        HelpBodyText(section.body)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Color(UIColor.systemBackground))
        .navigationTitle(article.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Inline SF Symbol renderer
//
// Parses tokens of the form [sf:symbol.name] in body text and replaces them
// with the actual SF Symbol image inline. Everything else renders as plain text.
//
// Uses LocalizedStringKey string interpolation (appendInterpolation) to mix
// text segments and SF Symbol images without the deprecated Text + operator.

private func HelpBodyText(_ raw: String) -> Text {
    let pattern = #"\[sf:([^\]]+)\]"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
        return Text(raw)
    }
    let ns = raw as NSString
    let fullRange = NSRange(location: 0, length: ns.length)
    let matches = regex.matches(in: raw, range: fullRange)

    // Build a LocalizedStringKey interpolation so the compiler uses
    // appendInterpolation(_: Image) and appendInterpolation(_: Text),
    // which are the non-deprecated paths on iOS 26.
    var interp = LocalizedStringKey.StringInterpolation(literalCapacity: raw.count,
                                                        interpolationCount: matches.count * 2)
    var cursor = 0

    for match in matches {
        let preRange = NSRange(location: cursor, length: match.range.location - cursor)
        if preRange.length > 0 {
            interp.appendLiteral(ns.substring(with: preRange))
        }
        let symbolName = ns.substring(with: match.range(at: 1))
        interp.appendInterpolation(Image(systemName: symbolName))
        cursor = match.range.location + match.range.length
    }

    if cursor < ns.length {
        interp.appendLiteral(ns.substring(from: cursor))
    }

    return Text(LocalizedStringKey(stringInterpolation: interp))
}
