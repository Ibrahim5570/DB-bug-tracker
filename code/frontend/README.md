# BugTracker Command Center — Frontend Documentation

> A high-tech, futuristic Bug Tracking dashboard built with **pure HTML5, Vanilla CSS3, and Vanilla JavaScript (ES6+)** — no frameworks, no build tools.

---

## Table of Contents

1. [Tech Stack & Architecture](#tech-stack--architecture)
2. [File Structure](#file-structure)
3. [How to Run](#how-to-run)
4. [Design System](#design-system)
5. [index.html — Structure Breakdown](#indexhtml--structure-breakdown)
6. [style.css — Styling Breakdown](#stylecss--styling-breakdown)
7. [app.js — Logic Breakdown](#appjs--logic-breakdown)
8. [API Endpoints Used](#api-endpoints-used)
9. [SPA Routing Flow](#spa-routing-flow)

---

## Tech Stack & Architecture

| Layer      | Technology                        |
|------------|-----------------------------------|
| Structure  | Pure HTML5 (semantic elements)    |
| Styling    | Vanilla CSS3 (Grid, Flexbox, CSS Variables, Keyframes) |
| Logic      | Vanilla JavaScript ES6+ (`fetch()`, DOM manipulation)  |
| Fonts      | Google Fonts — Space Grotesk, JetBrains Mono           |
| Icons      | Phosphor Icons CDN (`@phosphor-icons/web`)             |
| Backend    | FastAPI at `http://127.0.0.1:8000`                     |
| Database   | SQL Server (BugTrackerDB) via pyodbc                   |

The frontend is a **Single Page Application (SPA)** — all views exist in `index.html` and JavaScript toggles visibility via CSS classes. There are no page reloads.

---

## File Structure

```
frontend/
├── index.html    # All HTML structure — sidebar, 4 views, 2 modals, toast container
├── style.css     # Complete design system — dark theme, glassmorphism, neon glows, animations
├── app.js        # All application logic — API calls, rendering, form handling, SPA routing
└── README.md     # This documentation
```

---

## How to Run

```bash
# 1. Start the FastAPI backend (from the project root)
uvicorn main:app --reload --port 8000

# 2. Serve the frontend (from the project root)
python -m http.server 5500 --directory frontend

# 3. Open in browser
http://localhost:5500
```

---

## Design System

### Theme & Colors

All colors are defined as CSS custom properties in `:root` (style.css, lines 4–29):

| Variable         | Value                        | Usage                          |
|------------------|------------------------------|--------------------------------|
| `--bg-deep`      | `#05050A`                    | Page background (near-black)   |
| `--bg-panel`     | `rgba(12, 12, 22, 0.55)`    | Glass panel backgrounds        |
| `--cyan`         | `#00E5FF`                    | Primary accent (Electric Cyan) |
| `--magenta`      | `#FF00FF`                    | Secondary accent (Deep Magenta)|
| `--green`        | `#39FF14`                    | Success states, low priority   |
| `--red`          | `#FF3D5A`                    | Errors, overdue, critical      |
| `--orange`       | `#FF9F1C`                    | Warnings, high priority        |
| `--yellow`       | `#FAFF00`                    | Medium priority                |
| `--text-primary` | `#E8E8F0`                    | Main text                      |
| `--text-secondary`| `#8888A0`                   | Subdued text                   |
| `--text-muted`   | `#555570`                    | Labels, hints                  |

### Typography

| Font             | Variable           | Usage                            |
|------------------|---------------------|----------------------------------|
| Space Grotesk    | `--font-display`    | Headings, nav labels, buttons    |
| JetBrains Mono   | `--font-mono`       | Data values, IDs, API responses, table cells |

### Glassmorphism

The `.glass-panel` class (style.css, lines 86–92) creates the frosted glass effect:
- Semi-transparent background (`rgba(12, 12, 22, 0.55)`)
- `backdrop-filter: blur(16px)` for the frosted look
- 1px border with `rgba(255,255,255,0.07)` for the subtle edge

### Neon Glow Effects

Glows are achieved via CSS `box-shadow` with accent color at low opacity:
- Button hover: `box-shadow: 0 0 25px var(--cyan-dim)`
- Card hover: `box-shadow: 0 0 30px rgba(0,229,255,0.06)`
- Status dot: `box-shadow: 0 0 8px var(--green), 0 0 20px var(--green-dim)`
- Priority bar fills: each has its own `box-shadow` glow matching its color

---

## index.html — Structure Breakdown

### Ambient Background (lines 21–27)
```html
<div class="ambient-bg">
  <div class="orb orb-1"></div>   <!-- Cyan gradient orb, top-left -->
  <div class="orb orb-2"></div>   <!-- Magenta gradient orb, bottom-right -->
  <div class="orb orb-3"></div>   <!-- Green gradient orb, center -->
  <div class="grid-lines"></div>  <!-- Subtle grid pattern overlay -->
</div>
```
These are purely decorative. Three blurred radial gradients float with CSS keyframe animations, creating the "bio-luminescent laboratory" atmosphere. The grid lines overlay adds a subtle tech-grid pattern.

---

### Sidebar (lines 29–76)

```html
<aside class="sidebar" id="sidebar">
```

| Section | Lines | Purpose |
|---------|-------|---------|
| Logo/Brand | 31–38 | Bug beetle icon + "BUGTRACKER" text + collapse toggle button |
| Navigation | 41–67 | 4 nav links with `data-view` attributes for SPA routing |
| Health Indicator | 70–75 | Green/red dot + label showing DB connection status |

**Navigation links** use `data-view` attributes to control which section is shown:

| Nav Link | `data-view` | Target View |
|----------|-------------|-------------|
| Command Center | `dashboard` | `#view-dashboard` |
| Report Anomaly | `report-bug` | `#view-report-bug` |
| Issue Registry | `issues` | `#view-issues` |
| Projects | `projects` | `#view-projects` |

---

### Dashboard View (lines 82–152)

`<section id="view-dashboard">` — The **Command Center**. Contains three data sections:

#### 1. Project Status Matrix (lines 103–112)
```html
<div class="project-grid" id="projectGrid">
  <!-- JS renders project cards here from GET /api/dashboard/project-stats -->
</div>
```
Each card shows: project name, status badge, total open issues count, and 4 priority bars (Critical/High/Medium/Low) with animated fills.

#### 2. Resource Capacity Table (lines 114–138)
```html
<table class="data-table" id="workloadTable">
  <!-- JS renders developer rows here from GET /api/dashboard/developer-workload -->
</table>
```
Columns: Developer Name, Role, Assigned, Active, Overdue (red if > 0), Resolved, Load bar (color-coded by percentage).

#### 3. Live Telemetry Feed (lines 140–151)
```html
<div class="activity-feed glass-panel" id="activityFeed">
  <div class="feed-list" id="feedList">
    <!-- JS renders activity items here from GET /api/dashboard/recent-activity -->
  </div>
</div>
```
Each entry shows: Issue ID badge (clickable), title, project, who changed it, old→new status transition chips, and timestamp.

---

### Report Bug View (lines 154–228)

`<section id="view-report-bug">` — The **Anomaly Submission** form.

| Field | Input Type | HTML ID | API Key |
|-------|-----------|---------|---------|
| Issue ID | `number` | `bugIssueId` | `issue_id` |
| Title | `text` | `bugTitle` | `title` |
| Priority | `select` (Low/Medium/High/Critical) | `bugPriority` | `priority` |
| Severity | `select` (Trivial/Minor/Major/Critical/Blocker) | `bugSeverity` | `severity` |
| Project ID | `number` | `bugProjectId` | `project_id` |
| Reporter ID | `number` | `bugReporterId` | `reporter_id` |
| Due Date | `date` | `bugDueDate` | `due_date` |

The form submits via JS `fetch()` to `POST /api/bugs/`. A response display area (`#bugResponse`) shows the JSON result.

---

### Issue Registry View (lines 230–266)

`<section id="view-issues">` — Full issue table.

Table columns: ID, Title, Type, Priority (color-coded), Status (color-coded), Due Date, Project, Reporter. Every row is clickable — opens the **Status Update Modal**.

---

### Projects View (lines 268–356)

`<section id="view-projects">` — Two sub-sections:

1. **All Projects Table** (lines 286–307) — Lists all projects from `GET /api/projects`. Clickable rows open the Project Status Modal.

2. **Create New Project Form** (lines 309–355) — Fields:

| Field | HTML ID | API Key |
|-------|---------|---------|
| Project ID | `projId` | `project_id` |
| Project Name | `projName` | `name` |
| Description | `projDesc` | `description` |
| Start Date | `projStartDate` | `start_date` |
| Initial Status | `projFormStatus` | `status` |

Submits via `POST /api/projects/`.

---

### Issue Status Modal (lines 359–406)

```html
<div class="modal-overlay" id="statusModal">
```
A fixed-position overlay (hidden by default). Triggered by clicking any issue ID in the activity feed, issue registry, or project cards.

| Field | HTML ID | API Key |
|-------|---------|---------|
| Operator ID | `statusUserId` | `user_id` |
| New Status | `statusNewStatus` (select) | `new_status` |

Options: Open, In Progress, In Review, Done, Closed, Rejected. Submits via `PUT /api/issues/{issue_id}/status`.

---

### Project Status Modal (lines 408–445)

```html
<div class="modal-overlay" id="projectModal">
```
Same pattern as the issue modal but for projects. Triggered by clicking a project row.

| Field | HTML ID | API Key |
|-------|---------|---------|
| New Status | `projNewStatus` (select) | `new_status` |

Options: Active, On Hold, Completed, Archived. Submits via `PUT /api/projects/{project_id}/status`.

---

### Toast Container (lines 447–448)

```html
<div class="toast-container" id="toastContainer"></div>
```
Fixed at bottom-right. JS dynamically appends toast notifications (success = green, error = red) that auto-dismiss after 3.6 seconds.

---

## style.css — Styling Breakdown

| Section | Lines | What It Does |
|---------|-------|--------------|
| **CSS Variables & Theme** | 1–29 | All color tokens, font families, sizing variables, transition timing |
| **Reset & Base** | 31–43 | Box-sizing reset, body background, font smoothing |
| **Ambient Background** | 45–81 | Floating orbs with `blur(120px)`, grid line overlay, `@keyframes float-orb` animation (18–25s cycle) |
| **Glass Panel Utility** | 83–92 | `.glass-panel` — reusable frosted glass card with backdrop blur |
| **Sidebar** | 94–176 | Fixed left panel, collapse behavior, nav link active states with left border glow, health dot pulse animation |
| **Main Content** | 178–217 | Left margin offset matching sidebar width, view show/hide with `@keyframes fadeInView` |
| **Section Blocks** | 219–228 | Spacing and uppercase section titles with icon styling |
| **Project Cards Grid** | 230–306 | CSS Grid auto-fill layout, card hover glow + lift, gradient top border on hover, priority bar fills with color-coded box-shadows |
| **Workload Table** | 308–341 | Data table styling, monospace cells, row hover highlight, load bar with green/orange/red color classes |
| **Activity Feed** | 343–402 | Scrollable feed with custom scrollbar, `@keyframes slideInFeed` entrance animation, issue ID badges, status transition chips |
| **Buttons** | 404–438 | `.btn-ghost` (transparent), `.btn-primary` (gradient + glow), `.btn-glow` (sweep reflection effect on hover), `.btn-success` (green flash) |
| **Forms** | 440–482 | Transparent inputs with bottom-border-only, cyan glow on `:focus`, select dropdown styling, response display box |
| **Modal** | 484–522 | Fixed overlay with backdrop blur, `@keyframes modalIn` entrance animation (scale + fade), close button hover turns red |
| **Toast Notifications** | 524–554 | Fixed bottom-right stack, success (green) and error (red) variants, `@keyframes toastIn` slide-in + `toastOut` fade-out |
| **Responsive** | 556–566 | At `≤900px`: sidebar collapses, form grid becomes single column, project cards stack |

### Key CSS Techniques

**Glassmorphism recipe:**
```css
background: rgba(12, 12, 22, 0.55);
border: 1px solid rgba(255,255,255,0.07);
backdrop-filter: blur(16px);
```

**Neon glow on hover:**
```css
.project-card:hover {
  border-color: rgba(0,229,255,0.15);
  box-shadow: 0 0 30px rgba(0,229,255,0.06), inset 0 0 30px rgba(0,229,255,0.02);
  transform: translateY(-2px);
}
```

**Button sweep reflection:**
```css
.btn-glow::after {
  content:''; position:absolute; top:0; left:-100%;
  width:60%; height:100%;
  background: linear-gradient(90deg, transparent, rgba(255,255,255,0.08), transparent);
  transition: left 0.5s ease;
}
.btn-glow:hover::after { left:120%; }
```

---

## app.js — Logic Breakdown

### Global Configuration (lines 1–8)

```js
const API_BASE = 'http://127.0.0.1:8000';
let useLiveAPI = true;    // Set to false to use mock data instead
let currentView = 'dashboard';
```

### Mock Data Fallback (lines 10–30)

The `MOCK` object contains sample data for every endpoint. If the API is unreachable, `fetchData()` falls back to these automatically — the UI never shows blank.

### DOM References (lines 32–78)

All `getElementById` / `querySelectorAll` calls are grouped here for every interactive element (sidebar, grids, tables, forms, modals, buttons).

### SPA Navigation (lines 80–108)

```
User clicks nav link → switchView(viewName) →
  1. Remove 'active' class from all nav links
  2. Add 'active' to clicked link
  3. Hide all <section class="view"> elements
  4. Show the target section with fadeInView animation
  5. Auto-load data for that view (loadDashboard/loadIssues/loadProjects)
```

The trick for re-triggering the CSS animation on view switch (lines 100–102):
```js
targetView.classList.remove('active');
void targetView.offsetHeight;        // Force reflow
targetView.classList.add('active');   // Re-triggers @keyframes fadeInView
```

### Data Fetching (lines 110–121)

```js
async function fetchData(endpoint, mockKey) {
  if (!useLiveAPI) return MOCK[mockKey];
  try {
    const res = await fetch(`${API_BASE}${endpoint}`);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    return await res.json();
  } catch (err) {
    console.warn(`API fetch failed, using mock:`, err);
    return MOCK[mockKey];   // Graceful fallback
  }
}
```

### Health Check (lines 123–140)

On boot, `checkHealth()` pings `GET /api/health`. If the DB responds:
- Green dot + "BugTrackerDB · Live" label
- Tooltip shows server name and time

If the API is down:
- Red dot + "DB Offline (mock)" label

### Render Functions

Each section has a dedicated render function that takes an array of objects and builds DOM elements:

| Function | Lines | Input API | Output |
|----------|-------|-----------|--------|
| `renderProjectCards(data)` | 142–177 | `/api/dashboard/project-stats` | Glass cards with priority bars |
| `pBar(label, count, max, cls)` | 179–186 | — | Helper: builds a single priority bar row |
| `renderWorkload(data)` | 188–209 | `/api/dashboard/developer-workload` | Table rows with load bars |
| `renderActivityFeed(data)` | 211–239 | `/api/dashboard/recent-activity` | Feed items with status transition chips |
| `renderIssuesTable(data)` | 241–269 | `/api/issues` | Full issue table with color-coded priority/status |
| `renderProjectsTable(data)` | 271–294 | `/api/projects` | Projects table with click-to-update-status |

### Data Loaders (lines 302–323)

```js
async function loadDashboard() {
  // Fetches all 3 dashboard endpoints in parallel
  const [projects, workload, activity] = await Promise.all([...]);
  renderProjectCards(projects);
  renderWorkload(workload);
  renderActivityFeed(activity);
  updateTimestamp();
}
```

`loadIssues()` and `loadProjects()` follow the same pattern but for single endpoints.

### Refresh Buttons (lines 325–333)

Each view's refresh button triggers a spin animation on its icon, then calls the appropriate load function:
```js
refreshBtn.addEventListener('click', () => spinRefresh(refreshBtn, loadDashboard));
```

### Issue Status Modal (lines 335–373)

**Flow:**
1. User clicks an issue ID or row → `openStatusModal(issueId, data)`
2. Modal opens showing issue info (ID, title, project, current status)
3. User enters their User ID and selects a new status
4. Form submit → `PUT /api/issues/{issue_id}/status` with `{ user_id, new_status }`
5. On success: button flashes green "Mutation Applied", toast appears, dashboard & issues auto-refresh
6. On error: red error response shown, error toast with the server's error message

### Project Status Modal (lines 375–410)

Same pattern as the issue modal:
1. User clicks a project card or table row → `openProjectModal(projectId, name, currentStatus)`
2. User selects new status (Active / On Hold / Completed / Archived)
3. Form submit → `PUT /api/projects/{project_id}/status` with `{ new_status }`
4. On success: auto-refreshes dashboard and projects list

### Bug Report Form (lines 412–443)

1. Intercepts form submit with `e.preventDefault()`
2. Builds JSON payload from all form fields
3. `POST /api/bugs/` with the payload
4. On success: button flashes green "Anomaly Logged", toast, auto-refreshes dashboard + issues
5. On error: shows detailed error message (e.g., trigger violations from the database)

### Project Create Form (lines 445–473)

Same pattern as bug form:
1. Builds payload: `{ project_id, name, description, start_date, status }`
2. `POST /api/projects/` 
3. On success: refreshes projects list and dashboard

### Helper Functions (lines 475–491)

| Function | Purpose |
|----------|---------|
| `showResponse(container, pre, data, ok)` | Displays JSON response in a styled `<pre>` block (cyan for success, red for error) |
| `showToast(message, type)` | Creates a toast notification element, appends to container, auto-removes after 3.6s |

### Boot Sequence (lines 498–502)

```js
document.addEventListener('DOMContentLoaded', () => {
  checkHealth();      // Ping DB, update sidebar indicator
  loadDashboard();    // Fetch and render all dashboard data
});
```

---

## API Endpoints Used

### Read Operations (GET)

| Endpoint | Called When | Renders |
|----------|-----------|---------|
| `GET /api/health` | Page load | Sidebar health dot |
| `GET /api/dashboard/project-stats` | Dashboard load/refresh | Project cards grid |
| `GET /api/dashboard/developer-workload` | Dashboard load/refresh | Workload table |
| `GET /api/dashboard/recent-activity` | Dashboard load/refresh | Activity feed |
| `GET /api/issues` | Issues view opened/refreshed | Issues table |
| `GET /api/projects` | Projects view opened/refreshed | Projects table |

### Write Operations (POST/PUT)

| Endpoint | Triggered By | Payload |
|----------|-------------|---------|
| `POST /api/bugs/` | Bug form submit | `{ issue_id, title, priority, project_id, reporter_id, due_date, severity }` |
| `POST /api/projects/` | Project form submit | `{ project_id, name, description, start_date, status }` |
| `PUT /api/issues/{id}/status` | Status modal submit | `{ user_id, new_status }` |
| `PUT /api/projects/{id}/status` | Project modal submit | `{ new_status }` |

---

## SPA Routing Flow

```
┌─────────────────────────────────────────────────────┐
│  Page Load                                          │
│  ├── checkHealth() → GET /api/health                │
│  └── loadDashboard() → 3x parallel GETs            │
│       ├── renderProjectCards()                      │
│       ├── renderWorkload()                          │
│       └── renderActivityFeed()                      │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│  Nav Click: "Report Anomaly"                        │
│  └── switchView('report-bug')                       │
│       └── Shows form (no data fetch needed)         │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│  Nav Click: "Issue Registry"                        │
│  └── switchView('issues')                           │
│       └── loadIssues() → GET /api/issues            │
│            └── renderIssuesTable()                  │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│  Nav Click: "Projects"                              │
│  └── switchView('projects')                         │
│       └── loadProjects() → GET /api/projects        │
│            └── renderProjectsTable()                │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│  Mutation Flow (any form submit)                    │
│  ├── POST/PUT to API                                │
│  ├── Show response in UI                            │
│  ├── Flash button green + show toast                │
│  └── Auto-refresh affected views (800ms delay)      │
└─────────────────────────────────────────────────────┘
```
