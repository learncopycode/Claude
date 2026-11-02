import SwiftUI
import SwiftData

/// Create a zikr by hand.
struct NewZikrSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var title = ""
    @State private var arabic = ""
    @State private var translation = ""
    @State private var target = 33

    var body: some View {
        NavigationStack {
            Form {
                Section("Zikr") {
                    TextField("Name (e.g. SubhanAllah)", text: $title)
                    TextField("Arabic (optional)", text: $arabic, axis: .vertical)
                        .multilineTextAlignment(.trailing)
                    TextField("Meaning (optional)", text: $translation, axis: .vertical)
                }
                Section("Target") {
                    TargetPicker(target: $target)
                }
            }
            .navigationTitle("New zikr")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        context.insert(ZikrItem(
                            title: title.trimmingCharacters(in: .whitespaces),
                            arabic: arabic,
                            translation: translation,
                            target: target
                        ))
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

/// Quick presets plus a stepper for the round size.
struct TargetPicker: View {
    @Binding var target: Int
    private let presets = [1, 3, 7, 33, 99, 100, 1000]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Stepper(value: $target, in: 0...100_000) {
                Text(target == 0 ? "No target (count freely)" : "\(target) per round")
                    .monospacedDigit()
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(presets, id: \.self) { value in
                        Button("\(value)") { target = value }
                            .buttonStyle(.bordered)
                            .tint(value == target ? Theme.green : .secondary)
                    }
                }
            }
        }
    }
}
