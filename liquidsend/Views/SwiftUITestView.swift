//
//  SwiftUITestView.swift
//  liquidsend
//
//  Created by liu zifa1 on 1/20/26.
//
/*
import SwiftUI

// MARK: - Sample model & dataset

// Sample data model
struct Item: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let score: Int
    let count: Int
}

enum Filtering: Int, CaseIterable, Hashable, Identifiable {
    case allMatches
    case topMatches
    case mostMatched

    var id: Int { rawValue }
    var title: String {
        switch self {
        case .allMatches: return "All"
        case .topMatches: return "Top"
        case .mostMatched: return "Count"
        }
    }
}

// Sample data to demonstrate filtering.
let items: [Item] = [
    Item(name: "Apple", score: 90, count: 12),
    Item(name: "Banana", score: 65, count: 5),
    Item(name: "Cherry", score: 78, count: 8),
    Item(name: "Date", score: 40, count: 3),
    Item(name: "Elderberry", score: 88, count: 15),
]

// MARK: - Main SwiftUI View
struct SwiftUITestView: View {
    @State private var shouldIMinimizeTabBar = false
    @State private var filtering: Filtering = .allMatches

    // Computed results based on the selected filter
    private var filteredItems: [Item] {
        switch filtering {
        case .allMatches:
            return items
        case .topMatches:
            // top matches: score >= 80, sorted by score descending
            return items.filter { $0.score >= 80 }.sorted { $0.score > $1.score }
        case .mostMatched:
            // most matched: sort by count descending
            return items.sorted { $0.count > $1.count }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(filteredItems) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name)
                                    .font(.headline)
                                Text("Score: \(item.score) • Count: \(item.count)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button {
                        // photo action
                    } label: {
                        Image(systemName: "photo.on.rectangle")
                    }
                }

                ToolbarItemGroup(placement: .bottomBar) {
                    Picker(selection: $filtering) {
                        ForEach(Filtering.allCases) { f in
                            Text(f.title).tag(f)
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                    }
                    .pickerStyle(.segmented)
                }
                .sharedBackgroundVisibility(.hidden)

                ToolbarItem(placement: .bottomBar) {
                    Button {
                        // play action
                    } label: {
                        Image(systemName: "play.fill")
                    }
                }
            }
            .navigationTitle("Filter Test")
        }
    }
}

#Preview {
    SwiftUITestView()
}
*/
