////
////  HelpModule.swift
////  Extend
////

import SwiftUI
import UIKit
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
                        HelpBodyView(raw: section.body)
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
// Splits the raw string into a flat array of segments (plain text or symbol name),
// then assembles a View using a helper that returns AnyView so the body property
// can lay out each segment. This sidesteps both the deprecated Text + operator
// and the LocalizedStringKey.StringInterpolation manual-append path that crashed
// the Swift 6.2 compiler.

// A parsed segment: either a run of plain text or an SF Symbol name.
private enum HelpSegment {
    case text(String)
    case symbol(String)
}

private func parseHelpSegments(_ raw: String) -> [HelpSegment] {
    let pattern = #"\[sf:([^\]]+)\]"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
        return [.text(raw)]
    }
    let ns = raw as NSString
    let matches = regex.matches(in: raw, range: NSRange(location: 0, length: ns.length))
    guard !matches.isEmpty else { return [.text(raw)] }

    var segments: [HelpSegment] = []
    var cursor = 0
    for match in matches {
        let preLen = match.range.location - cursor
        if preLen > 0 {
            segments.append(.text(ns.substring(with: NSRange(location: cursor, length: preLen))))
        }
        segments.append(.symbol(ns.substring(with: match.range(at: 1))))
        cursor = match.range.location + match.range.length
    }
    if cursor < ns.length {
        segments.append(.text(ns.substring(from: cursor)))
    }
    return segments
}

// Renders segments as a SwiftUI view. Plain-text runs become Text; symbols
// become Image views baseline-aligned with the text. Wrapped in a flowing
// layout using ViewThatFits isn't needed here — we just use an HStack with
// wrapping via a custom FlowLayout would be ideal, but for help body text a
// simple Text with per-segment rendering is sufficient.
//
// Since Text + Text is deprecated and LocalizedStringKey.StringInterpolation
// crashes swiftc 6.2, we render each segment as its own view inside a
// wrapping HStack that allows line wrapping.
struct HelpBodyView: View {
    let raw: String

    var body: some View {
        let segments = parseHelpSegments(raw)
        // If there are no symbols, just use a plain Text — fastest path.
        if !segments.contains(where: { if case .symbol = $0 { return true } else { return false } }) {
            Text(raw)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            // Render segments inline. Text views with embedded Image via
            // \(Image(systemName:)) string interpolation is the recommended
            // iOS 26 approach — we build one Text per segment and join with
            // a single string-interpolation Text at call site where possible.
            // Here we use a wrapping HStack with flexible layout.
            SegmentedHelpText(segments: segments)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
}

private struct SegmentedHelpText: View {
    let segments: [HelpSegment]

    var body: some View {
        buildText(from: segments)
            .fixedSize(horizontal: false, vertical: true)
    }

    // Recursively build a single Text by prepending each segment via
    // string interpolation — the iOS 26 recommended path that avoids
    // the deprecated + operator.
    private func buildText(from remaining: [HelpSegment]) -> Text {
        guard let first = remaining.first else { return Text(verbatim: "") }
        let rest = buildText(from: Array(remaining.dropFirst()))
        switch first {
        case .text(let s):
            return Text("\(Text(verbatim: s))\(rest)")
        case .symbol(let n):
            return Text("\(Image(systemName: n))\(rest)")
        }
    }
}
