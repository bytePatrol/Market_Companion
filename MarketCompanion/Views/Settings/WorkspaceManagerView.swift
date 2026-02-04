// WorkspaceManagerView.swift
// MarketCompanion
//
// Sheet for managing saved workspace layouts.

import SwiftUI

struct WorkspaceManagerView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var editingId: Int64?
    @State private var editName = ""
    @State private var newWorkspaceName = ""

    var body: some View {
        VStack(spacing: Spacing.lg) {
            HStack {
                Text("Workspace Layouts")
                    .font(AppFont.title())
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }

            // New workspace
            HStack(spacing: Spacing.sm) {
                TextField("New workspace name", text: $newWorkspaceName)
                    .textFieldStyle(.roundedBorder)
                    .help("Enter a name for the new workspace layout")

                Button("Save Current") {
                    let name = newWorkspaceName.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty else { return }
                    appState.saveWorkspace(name: name)
                    newWorkspaceName = ""
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(newWorkspaceName.trimmingCharacters(in: .whitespaces).isEmpty)
                .help("Save the current page, companion window state, and chart symbol as a named layout")
            }

            SubtleDivider()

            if appState.workspaces.isEmpty {
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "rectangle.stack")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.textTertiary)
                    Text("No saved workspaces")
                        .font(AppFont.body())
                        .foregroundStyle(Color.textSecondary)
                    Text("Save the current layout to quickly switch between configurations.")
                        .font(AppFont.caption())
                        .foregroundStyle(Color.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, Spacing.xl)
            } else {
                ScrollView {
                    VStack(spacing: Spacing.xs) {
                        ForEach(appState.workspaces) { workspace in
                            workspaceRow(workspace)
                        }
                    }
                }
            }
        }
        .padding(Spacing.xl)
        .frame(minWidth: 450, maxWidth: 450, minHeight: 300)
    }

    private func workspaceRow(_ workspace: WorkspaceLayout) -> some View {
        CardView(padding: Spacing.sm) {
            HStack(spacing: Spacing.md) {
                Image(systemName: "rectangle.stack")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.accentColor)

                if editingId == workspace.id {
                    TextField("Name", text: $editName)
                        .textFieldStyle(.roundedBorder)
                        .font(AppFont.body())
                        .onSubmit {
                            if let id = workspace.id {
                                do {
                                    try appState.workspaceRepo.rename(id: id, to: editName)
                                    appState.loadWorkspaces()
                                } catch {
                                    print("[Workspace] Rename failed: \(error)")
                                }
                            }
                            editingId = nil
                        }
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(workspace.name)
                            .font(AppFont.body())

                        HStack(spacing: Spacing.xs) {
                            Text(workspace.selectedPage)
                                .font(AppFont.caption())
                                .foregroundStyle(Color.textTertiary)
                            if let sym = workspace.chartSymbol {
                                Text(sym)
                                    .font(AppFont.caption())
                                    .foregroundStyle(Color.textSecondary)
                            }
                        }
                    }
                }

                Spacer()

                // Load button
                Button {
                    appState.loadWorkspace(workspace)
                    dismiss()
                } label: {
                    Text("Load")
                        .font(AppFont.caption())
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)

                // Context menu
                Menu {
                    Button("Rename") {
                        editingId = workspace.id
                        editName = workspace.name
                    }
                    Divider()
                    Button("Delete", role: .destructive) {
                        if let id = workspace.id {
                            appState.deleteWorkspace(id: id)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textTertiary)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 24)
            }
        }
    }
}
