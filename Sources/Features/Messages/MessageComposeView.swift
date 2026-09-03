import SwiftUI

/// Compose a new Synergia message. Librus picks recipients in two steps —
/// first a category (Nauczyciele, Wychowawcy…), then the people inside it — so the
/// picker mirrors that. Sending is confirmed explicitly before it leaves the device.
struct MessageComposeView: View {
    @Environment(DataRepository.self) private var repo
    @Environment(\.dismiss) private var dismiss

    @State private var categories: [MessagesClient.RecipientCategory] = []
    @State private var category: MessagesClient.RecipientCategory?
    @State private var selectedPeople: [MessagesClient.Recipient] = []

    @State private var subject = ""
    @State private var text = ""
    @State private var loading = true
    @State private var sending = false
    @State private var errorText: String?
    @State private var confirm = false

    private var selectedNames: String {
        selectedPeople.map(\.name).joined(separator: ", ")
    }

    private var canSend: Bool {
        !selectedPeople.isEmpty
            && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !sending
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Do") {
                    if loading {
                        HStack(spacing: Theme.Space.sm) {
                            ProgressView()
                            Text("Wczytywanie…").foregroundStyle(.secondary)
                        }
                    } else if !categories.isEmpty {
                        NavigationLink {
                            CategoryPicker(categories: categories,
                                           category: $category,
                                           selectedPeople: $selectedPeople)
                                .environment(repo)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(selectedPeople.isEmpty ? "Wybierz odbiorców" : selectedNames)
                                    .foregroundStyle(selectedPeople.isEmpty ? Color.secondary : Color.primary)
                                    .lineLimit(2)
                                if let category, !selectedPeople.isEmpty {
                                    Text(category.name).font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                    } else {
                        Text(errorText ?? "Nie udało się wczytać odbiorców.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }

                Section("Temat") {
                    TextField("Temat", text: $subject)
                }

                Section("Treść") {
                    TextEditor(text: $text).frame(minHeight: 180)
                }

                if let errorText, !categories.isEmpty {
                    Section {
                        Text(errorText)
                            .font(.footnote)
                            .foregroundStyle(Color.negative)
                            .textSelection(.enabled)
                    }
                }
            }
            .navigationTitle("Nowa wiadomość")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Wyślij") { confirm = true }.disabled(!canSend)
                }
            }
            .overlay {
                if sending {
                    ProgressView("Wysyłanie…")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
                }
            }
            .confirmationDialog("Wysłać wiadomość?", isPresented: $confirm, titleVisibility: .visible) {
                Button("Wyślij") { send() }
                Button("Anuluj", role: .cancel) {}
            } message: {
                Text("Do: \(selectedNames)\nTemat: \(subject.isEmpty ? "(bez tematu)" : subject)")
            }
            .task { await loadCategories() }
        }
    }

    private func loadCategories() async {
        loading = true
        let result = await repo.loadRecipientCategories()
        categories = result.categories
        errorText = result.error
        loading = false
    }

    private func send() {
        sending = true
        errorText = nil
        Task {
            let failure = await repo.sendMessage(
                to: selectedPeople.map(\.id), subject: subject, body: text, category: category)
            sending = false
            if let failure {
                errorText = failure
                Haptics.warning()
            } else {
                Haptics.success()
                dismiss()
            }
        }
    }
}

// MARK: - Step 1: category

private struct CategoryPicker: View {
    @Environment(DataRepository.self) private var repo
    let categories: [MessagesClient.RecipientCategory]
    @Binding var category: MessagesClient.RecipientCategory?
    @Binding var selectedPeople: [MessagesClient.Recipient]

    var body: some View {
        List(categories) { cat in
            NavigationLink {
                PeoplePicker(category: cat,
                             category_: $category,
                             selectedPeople: $selectedPeople)
                    .environment(repo)
            } label: {
                Text(cat.name).lineLimit(2)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.appGroupedBackground.ignoresSafeArea())
        .navigationTitle("Kategoria odbiorcy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Step 2: people in that category

private struct PeoplePicker: View {
    @Environment(DataRepository.self) private var repo
    @Environment(\.dismiss) private var dismiss

    let category: MessagesClient.RecipientCategory
    @Binding var category_: MessagesClient.RecipientCategory?
    @Binding var selectedPeople: [MessagesClient.Recipient]

    @State private var people: [MessagesClient.Recipient] = []
    @State private var allowsMultiple = true
    @State private var selected: Set<String> = []
    @State private var loading = true
    @State private var errorText: String?
    @State private var search = ""

    private var filtered: [MessagesClient.Recipient] {
        guard !search.isEmpty else { return people }
        return people.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        Group {
            if loading {
                ProgressView("Wczytywanie osób…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if people.isEmpty {
                ScrollView {
                    Text(errorText ?? "Brak osób w tej kategorii.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Theme.Space.lg)
                }
            } else {
                List(filtered) { person in
                    Button {
                        Haptics.selection()
                        toggle(person)
                    } label: {
                        HStack(spacing: Theme.Space.md) {
                            Text(person.name)
                                .foregroundStyle(Color.primary)
                                .lineLimit(2)
                            Spacer(minLength: Theme.Space.sm)
                            if selected.contains(person.id) {
                                Image(systemName: "checkmark")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .searchable(text: $search, prompt: "Szukaj osoby")
            }
        }
        .background(Color.appGroupedBackground.ignoresSafeArea())
        .navigationTitle(allowsMultiple ? "\(category.name) (\(selected.count))" : category.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .onChange(of: selected) { _, _ in publish() }
    }

    private func toggle(_ person: MessagesClient.Recipient) {
        if allowsMultiple {
            if selected.contains(person.id) { selected.remove(person.id) }
            else { selected.insert(person.id) }
        } else {
            selected = [person.id]
            publish()
            dismiss()
        }
    }

    private func publish() {
        category_ = category
        selectedPeople = people.filter { selected.contains($0.id) }
    }

    private func load() async {
        loading = true
        let result = await repo.loadRecipients(in: category)
        people = result.list?.people ?? []
        allowsMultiple = result.list?.allowsMultiple ?? true
        errorText = result.error
        // Restore previous ticks if we come back to the same category.
        if category_?.id == category.id {
            selected = Set(selectedPeople.map(\.id))
        } else {
            selected = []
        }
        loading = false
    }
}
