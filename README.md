# Taskly

A simple, minimal task manager for macOS, built with SwiftUI.

- Tasks with **title, due date, priority, project and status**
- Sorted automatically: **High → Normal → Low**, then by due date
- **New Task** button (top right, or `⌘N`) and an **Add task** row under the list
- Finished tasks hide in a collapsible **Completed** section — click it to open, click anywhere outside it (or press `Esc`) to close
- Sidebar: search, All Tasks / Today / Upcoming, Projects (click **+** to add, right-click to delete), Settings
- **Settings** (`⌘,`): theme (System / Light / Dark), relative or calendar dates, and fully editable priorities, statuses and projects (rename, recolor, reorder, add, delete), plus defaults for new tasks
- Deleting a task shows an **Undo** toast
- Data is saved automatically to `~/Library/Application Support/Taskly/data.json`

Requires **macOS 14 (Sonoma) or newer** and Xcode 15+ (or the Xcode Command Line Tools).

## Run it

**In Xcode (easiest for editing):**

```bash
open Package.swift
```

Then press **⌘R**.

**As a real app in your Applications folder:**

```bash
chmod +x build-app.sh
./build-app.sh --install
```

This builds `build/Taskly.app` and copies it to `/Applications`. Re-run it after you change the code.

## Where things live

| File | What it does |
| --- | --- |
| `Sources/Taskly/TasklyApp.swift` | App entry point, window style, menu shortcuts (`⌘N`, `⌘,`) |
| `Sources/Taskly/Models.swift` | Data types (task, priority, status, project, settings) and the default/sample data |
| `Sources/Taskly/Store.swift` | Loading/saving, sorting, filtering, add/edit/delete logic; the "click outside to close Completed" handler |
| `Sources/Taskly/Theme.swift` | Light/dark colors, color presets, date formatting, **column widths** |
| `Sources/Taskly/Views/ContentView.swift` | Overall layout (sidebar panel + main panel) and theme switching |
| `Sources/Taskly/Views/Sidebar.swift` | Left panel: search, lists, projects, settings |
| `Sources/Taskly/Views/TaskListView.swift` | Header, task list, Completed section, empty state, undo toast |
| `Sources/Taskly/Views/TaskRow.swift` | A single task row and the column header |
| `Sources/Taskly/Views/Components.swift` | Reusable pieces: pickers, date picker, check circle, icon buttons |
| `Sources/Taskly/Views/SettingsView.swift` | The Settings screen |

### Common tweaks

- **Colors / dark mode look** → `Palette.light` and `Palette.dark` in `Theme.swift`
- **Column widths** → `enum Col` in `Theme.swift`
- **Sort order** → `sortOpen` in `Store.swift`
- **Default priorities / statuses for a fresh install** → `defaultPriorities()` / `defaultStatuses()` in `Models.swift`
- **Start over with fresh sample data** → quit the app and delete `~/Library/Application Support/Taskly/data.json`
