//
//  AddChargerView.swift
//  CellMate
//
//  Created by Yufan on 21/10/2026.
//

import SwiftUI

struct AddChargerView: View {
    struct Draft {
        let name: String
        let brand: String
    }

    let onSave: (Draft) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var name = ""
    @State private var brand = ""

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name
        case brand
    }

    private var draft: Draft? {
        let cleanName = name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let cleanBrand = brand.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !cleanName.isEmpty, !cleanBrand.isEmpty else {
            return nil
        }

        return Draft(name: cleanName, brand: cleanBrand)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("Add a charger to match with your battery.")
                        .font(.subheadline)
                        .foregroundStyle(AppColor.textSecondary)

                    chargerDetails
                    informationNote
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.md)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .screenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()

                Button("Done") {
                    focusedField = nil
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            saveButton
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Button {
                dismiss()
            } label: {
                Label("Garage", systemImage: "chevron.left")
                    .font(.body)
                    .foregroundStyle(AppColor.accent)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to Garage")

            Text("Add charger")
                .font(.largeTitle.bold())
                .foregroundStyle(AppColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
        }
        .padding(.horizontal, Spacing.md)
    }

    private var chargerDetails: some View {
        VStack(spacing: 0) {
            inputRow(
                "Name",
                placeholder: "Bosch 4A",
                text: $name
            )
            .focused($focusedField, equals: .name)
            .submitLabel(.next)
            .onSubmit {
                focusedField = .brand
            }

            Divider()

            inputRow(
                "Brand",
                placeholder: "Bosch",
                text: $brand
            )
            .focused($focusedField, equals: .brand)
            .submitLabel(.done)
            .onSubmit {
                focusedField = nil
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            AppColor.card,
            in: RoundedRectangle(
                cornerRadius: Radius.card,
                style: .continuous
            )
        )
    }

    private func inputRow(
        _ title: String,
        placeholder: String,
        text: Binding<String>
    ) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(
                VStackLayout(
                    alignment: .leading,
                    spacing: Spacing.sm
                )
            )
            : AnyLayout(HStackLayout(spacing: Spacing.md))

        return layout {
            Text(title)
                .foregroundStyle(AppColor.textPrimary)

            TextField(placeholder, text: text)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(
                    dynamicTypeSize.isAccessibilitySize
                        ? .leading
                        : .trailing
                )
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .accessibilityLabel(title)
        }
        .font(.body)
        .padding(.vertical, Spacing.sm)
        .frame(minHeight: 56)
    }

    private var informationNote: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "info.circle")
                .accessibilityHidden(true)

            Text(
                "Use the details on your charger label. "
                + "Adding a charger records its details; "
                + "it does not verify compatibility with a battery."
            )
            .fixedSize(horizontal: false, vertical: true)
        }
        .font(.footnote)
        .foregroundStyle(AppColor.textSecondary)
        .accessibilityElement(children: .combine)
    }

    private var saveButton: some View {
        Button {
            guard let draft else { return }
            focusedField = nil
            onSave(draft)
        } label: {
            Text("Save charger")
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
        }
        .buttonStyle(.appPrimary)
        .disabled(draft == nil)
        .padding(Spacing.md)
        .background(AppColor.background)
    }
}

#Preview("Light") {
    NavigationStack {
        AddChargerView(onSave: { _ in })
    }
}

#Preview("Dark") {
    NavigationStack {
        AddChargerView(onSave: { _ in })
    }
    .preferredColorScheme(.dark)
}
