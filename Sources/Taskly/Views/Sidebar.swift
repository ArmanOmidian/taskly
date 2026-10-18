import SwiftUI

struct Sidebar: View {
    @EnvironmentObject private var store: TaskStore
    @EnvironmentObject private var ui: UIState
    @Environment(\.palette) private var palette

    @State private var addingProject = false
    @State private var newProjectName = ""
    @FocusState private var newProjectFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            searchField
                .padding(.bottom, 16)

            SectionLabel(title: "Tasks")
            SidebarRow(item: .all, title: "All Tasks", count: store.openCount(.all)) {
                Image(systemName: "tray")
            }
            SidebarRow(item: .today, title: "Today", count: store.openCount(.today)) {
                Image(systemName: "sun.max")
            }
            SidebarRow(item: .upcoming, title: "Upcoming", count: store.openCount(.upcoming)) {
                Image(systemName: "calendar")
            }

            HStack {
                SectionLabel(title: "Projects")
                Spacer()
                IconButton(systemName: "plus", help: "New project") { startAddingProject() }
            }
            .padding(.top, 18)

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(store.data.projects) { p in
                        SidebarRow(item: .project(p.id), title: p.name.isEmpty ? "Untitled" : p.name,
                                   count: store.openCount(.project(p.id))) {
                            Circle().fill(Color(hex: p.colorHex)).frame(width: 8, height: 8)
                        }
                        .contextMenu {
                            Button("Delete Project", role: .destructive) {
                                if ui.selection == .project(p.id) { ui.selection = .all }
                                store.deleteProject(p.id)
                            }
                        }
                    }

                    if addingProject {
                        HStack(spacing: 10) {
                            Circle().strokeBorder(palette.tertiaryText, lineWidth: 1.5)
                                .frame(width: 8, height: 8)
                                .frame(width: 18)
                            TextField("Project name", text: $newProjectName)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13))
                                .focused($newProjectFocused)
                                .onSubmit { commitProject() }
                                .onExitCommand { cancelProject() }
                        }
                        .padding(.horizontal, 10)
                        .frame(height: 32)
                        .background(RoundedRectangle(cornerRadius: 8).fill(palette.hover))
                    }

                    if store.data.projects.isEmpty && !addingProject {
                        Text("No projects yet")
                            .font(.system(size: 12))
                            .foregroundStyle(palette.tertiaryText)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                    }
                }
            }
            .scrollIndicators(.never)

            Spacer(minLength: 12)

            SidebarRow(item: .settings, title: "Settings", count: nil) {
                Image(systemName: "gearshape")
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 44)   // room for the window's traffic-light buttons
        .padding(.bottom, 12)
        .onChange(of: newProjectFocused) { _, isFocused in
            if !isFocused && addingProject { commitProject() }
        }
    }

    private var searchField: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(palette.tertiaryText)
            TextField("Search", text: $ui.search)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
            if !ui.search.isEmpty {
                Button { ui.search = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(palette.tertiaryText)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(RoundedRectangle(cornerRadius: 8).fill(palette.inset))
    }

    private func startAddingProject() {
        addingProject = true
        newProjectName = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { newProjectFocused = true }
    }

    private func commitProject() {
        let name = newProjectName.trimmingCharacters(in: .whitespaces)
        addingProject = false
        newProjectName = ""
        guard !name.isEmpty else { return }
        let id = store.addProject(name: name)
        ui.selection = .project(id)
    }

    private func cancelProject() {
        newProjectName = ""
        addingProject = false
    }
}

struct SectionLabel: View {
    let title: String
    @Environment(\.palette) private var palette

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 10.5, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(palette.tertiaryText)
            .padding(.horizontal, 10)
            .padding(.bottom, 4)
    }
}

struct SidebarRow<Icon: View>: View {
    let item: SidebarItem
    let title: String
    let count: Int?
    @ViewBuilder var icon: () -> Icon

    @EnvironmentObject private var ui: UIState
    @Environment(\.palette) private var palette
    @State private var hover = false

    var body: some View {
        let selected = ui.selection == item
        Button { ui.selection = item } label: {
            HStack(spacing: 10) {
                icon()
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(selected ? palette.primaryText : palette.secondaryText)
                    .frame(width: 18)
                Text(title)
                    .font(.system(size: 13, weight: selected ? .semibold : .regular))
                    .foregroundStyle(palette.primaryText)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let count, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(palette.tertiaryText)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(RoundedRectangle(cornerRadius: 8).fill(selected ? palette.pill : (hover ? palette.hover : Color.clear)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}
