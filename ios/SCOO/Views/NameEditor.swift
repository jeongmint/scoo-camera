import SwiftUI

/// A name field for a friend or a baby. Rude or strange names are refused as you type (`NameFilter`);
/// leaving it empty keeps the default name.
struct NameEditor: View {
    /// The name used when none is given (the character's own name, or the baby's made-up name).
    let fallback: String
    /// The name given before, if any.
    var current: String? = nil
    var buttonTitle = "이름 정하기"
    /// Saves the name (nil = back to the default). Throws with a message the user can read.
    let save: (String?) throws -> Void
    @State private var text = ""
    @State private var note: String?
    @State private var noteIsProblem = false
    @FocusState private var focused: Bool

    private var problem: NameFilter.Problem? {
        NameFilter.clean(text).isEmpty ? nil : NameFilter.problem(text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                TextField(fallback, text: $text)
                    .textFieldStyle(.roundedBorder)
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit(commit)
                    .accessibilityLabel("이름, 비워 두면 \(fallback)")
                Button(buttonTitle, action: commit)
                    .font(.subheadline.weight(.semibold))
                    .disabled(problem != nil)
            }
            if let problem {
                Text(problem.message).font(.caption2).foregroundStyle(.red)
            } else if let note {
                Text(note).font(.caption2).foregroundStyle(noteIsProblem ? .red : Palette.moss)
            } else {
                Text("비워 두면 원래 이름 ‘\(fallback)’ 그대로예요. \(NameFilter.maxLength)글자까지, 이 iPhone에만 남아요.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .onAppear { text = current ?? "" }
    }

    private func commit() {
        guard problem == nil else { return }
        do {
            let clean = NameFilter.clean(text)
            try save(clean.isEmpty ? nil : clean)
            note = clean.isEmpty ? "원래 이름 ‘\(fallback)’ 그대로예요." : "이름을 정했어요: \(clean)"
            noteIsProblem = false
            focused = false
        } catch {
            note = error.localizedDescription
            noteIsProblem = true
        }
    }
}
