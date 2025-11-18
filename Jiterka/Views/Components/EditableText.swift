//
//  EditableText.swift
//  Jiterka
//
//  Inline editable text component with hover-to-edit UX
//

import SwiftUI

struct EditableText: View {
    let text: String
    let font: Font
    let fontWeight: Font.Weight
    let onSave: (String) -> Void

    @State private var isEditing = false
    @State private var editedText = ""
    @State private var isHovering = false
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            if isEditing {
                HStack(spacing: 6) {
                    TextField("Meeting name", text: $editedText)
                        .textFieldStyle(.plain)
                        .font(font)
                        .fontWeight(fontWeight)
                        .focused($isFocused)
                        .onSubmit {
                            saveChanges()
                        }
                        .onKeyPress(.escape) {
                            cancelEditing()
                            return .handled
                        }

                    Button {
                        saveChanges()
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                    .help("Save (Enter)")

                    Button {
                        cancelEditing()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                    .help("Cancel (Esc)")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.accentColor, lineWidth: 1.5)
                )
            } else {
                Button {
                    startEditing()
                } label: {
                    HStack(spacing: 6) {
                        Text(text)
                            .font(font)
                            .fontWeight(fontWeight)
                            .foregroundStyle(.primary)

                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .opacity(isHovering ? 1 : 0)
                    }
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    isHovering = hovering
                }
                .help("Click to edit")
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isEditing)
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .onDisappear {
            if isEditing {
                cancelEditing()
            }
        }
        .onChange(of: text) {
            if isEditing {
                cancelEditing()
            }
        }
        .onChange(of: isFocused) {
            if !isFocused && isEditing {
                saveChanges()
            }
        }
    }

    private func startEditing() {
        editedText = text
        isEditing = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isFocused = true
        }
    }

    private func saveChanges() {
        let trimmed = editedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && trimmed != text {
            onSave(trimmed)
        }
        isEditing = false
    }

    private func cancelEditing() {
        editedText = text
        isEditing = false
    }
}
