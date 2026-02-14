////
////  SearchField.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/13/26.
////

import SwiftUI

struct SearchField: View {
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            ZStack(alignment: .trailing) {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.roundedBorder)
                if !text.isEmpty {
                    Button(action: { text = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.black)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 8)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    @Previewable @State var text = ""
    SearchField(text: $text, placeholder: "Search...")
}
