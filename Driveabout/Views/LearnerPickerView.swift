import SwiftUI

struct LearnerPickerView: View {
    @EnvironmentObject private var visitStore: VisitStore

    @State private var newLearnerName = ""
    @State private var showingAddLearner = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Choose who you are supervising today. Each learner keeps their own map progress.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("Learners") {
                    if visitStore.learners.isEmpty {
                        Text("Add your first learner to get started.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(visitStore.learners) { learner in
                            Button {
                                visitStore.selectLearner(learner.id)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "person.crop.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(.blue)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(learner.displayName)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        Text(progressLabel(for: learner.id))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                }

                Section {
                    Button {
                        showingAddLearner = true
                    } label: {
                        Label("Add learner", systemImage: "plus.circle.fill")
                    }
                }
            }
            .navigationTitle("Who's driving?")
            .alert("Add learner", isPresented: $showingAddLearner) {
                TextField("First name", text: $newLearnerName)
                Button("Add") {
                    let trimmed = newLearnerName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    visitStore.addLearner(named: trimmed)
                    newLearnerName = ""
                }
                Button("Cancel", role: .cancel) {
                    newLearnerName = ""
                }
            } message: {
                Text("Enter the learner's name. You can add more teenagers later.")
            }
        }
    }

    private func progressLabel(for learnerID: UUID) -> String {
        let count = visitStore.exploredCellCount(for: learnerID)
        if count == 0 {
            return "No map progress yet"
        }
        return "\(count) areas explored"
    }
}

#Preview {
    LearnerPickerView()
        .environmentObject(VisitStore())
}
