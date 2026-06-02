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
        .navigationTitle("Help")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $store.searchText, prompt: "Search help topics...")
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
                        Text(section.body)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .navigationTitle(article.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
