//
//  AddBatteryView.swift
//  CellMate
//
//  Created by Yufan on 21/10/2026.
//

import SwiftUI

struct AddBatteryView: View {
    struct ChargerOption: Identifiable, Hashable {
        let id: UUID
        let name: String
    }

    struct Draft {
        let name: String
        let brand: String
        let capacityWh: Double
        let purchaseDate: Date
        let chargerID: UUID
    }

    let chargers: [ChargerOption]
    let onSave: (Draft) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var name = ""
    @State private var brand = ""
    @State private var capacity = ""
    @State private var purchaseDate = Date()
    @State private var selectedChargerID: UUID?

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name
        case brand
        case capacity
    }

    private var draft: Draft? {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanBrand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCapacity = capacity.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !cleanName.isEmpty,
              !cleanBrand.isEmpty,
              let capacityWh = try? Double(
                  cleanCapacity,
                  format: .number.locale(.current)
              ),
              capacityWh.isFinite,
              capacityWh > 0,
              let chargerID = selectedChargerID,
              chargers.contains(where: { $0.id == chargerID })
        else {
            return nil
        }

        return Draft(
            name: cleanName,
            brand: cleanBrand,
            capacityWh: capacityWh,
            purchaseDate: purchaseDate,
            chargerID: chargerID
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("A few details help keep your records useful.")
                        .font(.subheadline)
                        .foregroundStyle(AppColor.textSecondary)

                    batteryDetails

                    Text("MATCHED CHARGER")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColor.textSecondary)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, Spacing.xs)

                    chargerDetails
                    capacityNote
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

            Text("Add battery")
                .font(.largeTitle.bold())
                .foregroundStyle(AppColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
        }
        .padding(.horizontal, Spacing.md)
    }

    private var batteryDetails: some View {
        VStack(spacing: 0) {
            inputRow("Name", placeholder: "Battery A", text: $name)
                .focused($focusedField, equals: .name)
                .submitLabel(.next)
                .onSubmit { focusedField = .brand }

            Divider()

            inputRow("Brand", placeholder: "Bosch", text: $brand)
                .focused($focusedField, equals: .brand)
                .submitLabel(.next)
                .onSubmit { focusedField = .capacity }

            Divider()

            inputRow(
                "Capacity",
                placeholder: "720 Wh",
                text: $capacity
            )
            .keyboardType(.decimalPad)
            .focused($focusedField, equals: .capacity)

            Divider()

            DatePicker(
                "Date bought",
                selection: $purchaseDate,
                in: ...Date(),
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .font(.body)
            .foregroundStyle(AppColor.textPrimary)
            .tint(AppColor.accent)
            .padding(.vertical, Spacing.sm)
            .frame(minHeight: 56)
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
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.sm))
            : AnyLayout(HStackLayout(spacing: Spacing.md))

        return layout {
            Text(title)
                .foregroundStyle(AppColor.textPrimary)

            TextField(placeholder, text: text)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(
                    dynamicTypeSize.isAccessibilitySize ? .leading : .trailing
                )
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .accessibilityLabel(
                    title == "Capacity" ? "Capacity in watt-hours" : title
                )
        }
        .font(.body)
        .padding(.vertical, Spacing.sm)
        .frame(minHeight: 56)
    }

    private var chargerDetails: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Picker("Charger", selection: $selectedChargerID) {
                Text("Select charger")
                    .tag(nil as UUID?)

                ForEach(chargers) { charger in
                    Text(charger.name)
                        .tag(Optional(charger.id))
                }
            }
            .pickerStyle(.menu)
            .tint(AppColor.accent)
            .frame(minHeight: 44)
            .disabled(chargers.isEmpty)

            Text(
                chargers.isEmpty
                    ? "Add a charger in Garage before saving a battery."
                    : "Use the charger approved for this battery."
            )
            .font(.footnote)
            .foregroundStyle(AppColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.xs)
        .padding(.bottom, Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            AppColor.card,
            in: RoundedRectangle(
                cornerRadius: Radius.card,
                style: .continuous
            )
        )
    }

    private var capacityNote: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "info.circle")
                .accessibilityHidden(true)

            Text(
                "Can't find the capacity? Check the label or "
                + "manufacturer's guide before entering a value."
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
            Text("Save battery")
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
        AddBatteryView(
            chargers: [
                .init(id: UUID(), name: "Bosch 4A"),
                .init(id: UUID(), name: "Segway 2A")
            ],
            onSave: { _ in }
        )
    }
}

#Preview("Dark") {
    NavigationStack {
        AddBatteryView(
            chargers: [
                .init(id: UUID(), name: "Bosch 4A")
            ],
            onSave: { _ in }
        )
    }
    .preferredColorScheme(.dark)
}
