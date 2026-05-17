/* ============================================================
   BugTracker Command Center — app.js
   Pure Vanilla JS SPA with live API integration
   ============================================================ */

const API_BASE = 'http://127.0.0.1:8000';
let useLiveAPI = true;
let currentView = 'dashboard';

// ─── Mock Data (fallback only) ──────────────────────────────
const MOCK = {
  projectStats: [
    { ProjectID:1, ProjectName:"Project Alpha", ProjectStatus:"Active", TotalOpenIssues:14, Critical:3, High:4, Medium:5, Low:2 },
    { ProjectID:2, ProjectName:"Project Beta",  ProjectStatus:"Active", TotalOpenIssues:8,  Critical:1, High:2, Medium:3, Low:2 },
    { ProjectID:3, ProjectName:"Project Gamma", ProjectStatus:"On Hold",TotalOpenIssues:5,  Critical:0, High:1, Medium:2, Low:2 },
  ],
  devWorkload: [
    { UserID:1, DeveloperName:"Alice Chen", Role:"Lead Dev", TotalAssigned:8, ActiveIssues:5, OverdueIssues:1, Resolved:12 },
    { UserID:2, DeveloperName:"Bob Martinez", Role:"Backend Dev", TotalAssigned:6, ActiveIssues:4, OverdueIssues:0, Resolved:9 },
  ],
  recentActivity: [
    { HistoryID:1, ChangedAt:"2026-05-17T12:45:00", IssueID:1, IssueTitle:"Issue 1", IssueType:"Bug", ProjectName:"Project Alpha", ChangedByName:"Alice", OldStatus:"Open", NewStatus:"In Progress" },
  ],
  issues: [
    { IssueID:1, Title:"Issue 1", Type:"Bug", Priority:"High", Status:"Open", DueDate:"2026-05-20", ProjectID:1, ReporterID:1 },
  ],
  projects: [
    { ProjectID:1, Name:"Project Alpha", Description:"Core Platform", StartDate:"2026-01-01", EndDate:null, Status:"Active" },
  ]
};

// ─── DOM References ─────────────────────────────────────────
const sidebar       = document.getElementById('sidebar');
const sidebarToggle = document.getElementById('sidebarToggle');
const navLinks      = document.querySelectorAll('.nav-link');
const views         = document.querySelectorAll('.view');
const projectGrid   = document.getElementById('projectGrid');
const workloadBody  = document.getElementById('workloadBody');
const feedList      = document.getElementById('feedList');
const lastUpdated   = document.getElementById('lastUpdated');
const refreshBtn    = document.getElementById('refreshDashboard');

const issuesBody    = document.getElementById('issuesBody');
const refreshIssBtn = document.getElementById('refreshIssues');

const projectsBody  = document.getElementById('projectsBody');
const refreshProjBtn= document.getElementById('refreshProjects');

// Issue Status Modal
const statusModal   = document.getElementById('statusModal');
const modalClose    = document.getElementById('modalClose');
const modalCancel   = document.getElementById('modalCancel');
const modalInfo     = document.getElementById('modalIssueInfo');
const statusForm    = document.getElementById('statusForm');
const statusResp    = document.getElementById('statusResponse');
const statusRespPre = document.getElementById('statusResponseContent');

// Project Status Modal
const projectModal      = document.getElementById('projectModal');
const projModalClose    = document.getElementById('projModalClose');
const projModalCancel   = document.getElementById('projModalCancel');
const projModalInfo     = document.getElementById('projModalInfo');
const projStatusForm    = document.getElementById('projStatusForm');
const projStatusResp    = document.getElementById('projStatusResponse');
const projStatusRespPre = document.getElementById('projStatusResponseContent');

// Bug form
const bugForm    = document.getElementById('bugForm');
const bugResp    = document.getElementById('bugResponse');
const bugRespPre = document.getElementById('bugResponseContent');

// Project form
const projectForm    = document.getElementById('projectForm');
const projResp       = document.getElementById('projResponse');
const projRespPre    = document.getElementById('projResponseContent');

let activeIssueId   = null;
let activeProjectId = null;

// ─── Sidebar Toggle ─────────────────────────────────────────
sidebarToggle.addEventListener('click', () => sidebar.classList.toggle('collapsed'));

// ─── Navigation (SPA routing) ───────────────────────────────
navLinks.forEach(link => {
  link.addEventListener('click', (e) => {
    e.preventDefault();
    switchView(link.dataset.view);
  });
});

function switchView(viewName) {
  currentView = viewName;
  navLinks.forEach(l => l.classList.remove('active'));
  const activeNav = document.querySelector(`[data-view="${viewName}"]`);
  if (activeNav) activeNav.classList.add('active');

  views.forEach(v => v.classList.remove('active'));
  const targetView = document.getElementById(`view-${viewName}`);
  if (targetView) {
    targetView.classList.remove('active');
    void targetView.offsetHeight;
    targetView.classList.add('active');
  }

  if (viewName === 'issues') loadIssues();
  if (viewName === 'dashboard') loadDashboard();
  if (viewName === 'projects') loadProjects();
}

// ─── Data Fetching ──────────────────────────────────────────
async function fetchData(endpoint, mockKey) {
  if (!useLiveAPI) return MOCK[mockKey];
  try {
    const res = await fetch(`${API_BASE}${endpoint}`);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    return await res.json();
  } catch (err) {
    console.warn(`API fetch failed for ${endpoint}, using mock:`, err);
    return MOCK[mockKey];
  }
}

// ─── Health Check ───────────────────────────────────────────
async function checkHealth() {
  const dot   = document.getElementById('healthDot');
  const label = document.getElementById('healthLabel');
  try {
    const res = await fetch(`${API_BASE}/api/health`);
    const data = await res.json();
    dot.style.background = 'var(--green)';
    dot.style.boxShadow  = '0 0 8px var(--green), 0 0 20px var(--green-dim)';
    label.textContent = `${data.database} · Live`;
    label.title = `Server: ${data.server} | Time: ${data.server_time}`;
    console.log('✅ DB Health:', data);
  } catch {
    dot.style.background = 'var(--red)';
    dot.style.boxShadow  = '0 0 8px var(--red)';
    label.textContent = 'DB Offline (mock)';
  }
}

// ─── Render: Project Status Cards ───────────────────────────
function renderProjectCards(data) {
  projectGrid.innerHTML = '';
  const maxP = Math.max(...data.map(p => Math.max(p.Critical, p.High, p.Medium, p.Low, 1)));

  data.forEach((proj, idx) => {
    const badgeClass = proj.ProjectStatus === 'Active' ? 'badge-active'
                     : proj.ProjectStatus === 'On Hold' ? 'badge-onhold' : 'badge-completed';
    const card = document.createElement('div');
    card.className = 'project-card';
    card.style.animationDelay = `${idx * 0.08}s`;
    card.style.cursor = 'pointer';
    card.title = 'Click to update project status';
    card.innerHTML = `
      <div class="card-header">
        <span class="card-project-name">${proj.ProjectName}</span>
        <span class="card-status-badge ${badgeClass}">${proj.ProjectStatus}</span>
      </div>
      <div class="card-total">
        <span class="card-total-num">${proj.TotalOpenIssues}</span>
        <span class="card-total-label">open issues</span>
      </div>
      <div class="priority-bars">
        ${pBar('Critical', proj.Critical, maxP, 'fill-critical')}
        ${pBar('High',     proj.High,     maxP, 'fill-high')}
        ${pBar('Medium',   proj.Medium,   maxP, 'fill-medium')}
        ${pBar('Low',      proj.Low,      maxP, 'fill-low')}
      </div>
    `;
    // Click card to update project status
    card.addEventListener('click', () => {
      openProjectModal(proj.ProjectID, proj.ProjectName, proj.ProjectStatus);
    });
    projectGrid.appendChild(card);
  });
}

function pBar(label, count, max, cls) {
  const pct = max > 0 ? (count / max) * 100 : 0;
  return `<div class="priority-row">
    <span class="priority-label">${label}</span>
    <div class="priority-bar-bg"><div class="priority-bar-fill ${cls}" style="width:${pct}%"></div></div>
    <span class="priority-count">${count}</span>
  </div>`;
}

// ─── Render: Developer Workload ─────────────────────────────
function renderWorkload(data) {
  workloadBody.innerHTML = '';
  const maxA = Math.max(...data.map(d => d.TotalAssigned), 1);
  data.forEach(dev => {
    const pct = (dev.ActiveIssues / maxA) * 100;
    const cls = pct > 70 ? 'load-high' : pct > 40 ? 'load-med' : 'load-low';
    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td class="dev-name">${dev.DeveloperName}</td>
      <td>${dev.Role}</td>
      <td>${dev.TotalAssigned}</td>
      <td>${dev.ActiveIssues}</td>
      <td class="${dev.OverdueIssues > 0 ? 'overdue-cell' : ''}">${dev.OverdueIssues}</td>
      <td>${dev.Resolved}</td>
      <td><div class="load-bar-container">
        <div class="load-bar-bg"><div class="load-bar-fill ${cls}" style="width:${pct}%"></div></div>
        <span style="font-size:0.7rem;color:var(--text-muted)">${Math.round(pct)}%</span>
      </div></td>`;
    workloadBody.appendChild(tr);
  });
}

// ─── Render: Activity Feed ──────────────────────────────────
function renderActivityFeed(data) {
  feedList.innerHTML = '';
  data.forEach((item, idx) => {
    const el = document.createElement('div');
    el.className = 'feed-item';
    el.style.animationDelay = `${idx * 0.06}s`;
    const time = new Date(item.ChangedAt).toLocaleTimeString('en-US', { hour:'2-digit', minute:'2-digit', hour12:false });
    el.innerHTML = `
      <div class="feed-icon"><i class="ph ph-swap"></i></div>
      <div class="feed-body">
        <div class="feed-title">
          <span class="feed-issue-id" data-issue-id="${item.IssueID}" title="Click to update status">#${item.IssueID}</span>
          <span>${item.IssueTitle}</span>
        </div>
        <div class="feed-meta">
          <span>${item.ProjectName}</span><span>·</span>
          <span>${item.ChangedByName}</span><span>·</span>
          <span class="status-transition">
            <span class="status-chip status-chip-old">${item.OldStatus}</span>
            <span class="feed-arrow">→</span>
            <span class="status-chip status-chip-new">${item.NewStatus}</span>
          </span><span>·</span><span>${time}</span>
        </div>
      </div>`;
    el.addEventListener('click', () => openStatusModal(item.IssueID, item));
    feedList.appendChild(el);
  });
}

// ─── Render: Issues Table ───────────────────────────────────
function renderIssuesTable(data) {
  issuesBody.innerHTML = '';
  if (!data || !data.length) {
    issuesBody.innerHTML = '<tr><td colspan="8" style="text-align:center;color:var(--text-muted);padding:2rem;">No issues found</td></tr>';
    return;
  }
  data.forEach(issue => {
    const pColor = {Critical:'var(--red)',High:'var(--orange)',Medium:'var(--yellow)',Low:'var(--green)'}[issue.Priority] || 'var(--text-secondary)';
    const sColor = {'Open':'var(--cyan)','In Progress':'var(--orange)','In Review':'var(--magenta)','Done':'var(--green)','Closed':'var(--text-muted)','Rejected':'var(--red)'}[issue.Status] || 'var(--text-secondary)';
    const due = issue.DueDate ? new Date(issue.DueDate).toLocaleDateString('en-US',{month:'short',day:'numeric',year:'numeric'}) : '—';
    const tr = document.createElement('tr');
    tr.style.cursor = 'pointer';
    tr.innerHTML = `
      <td><span class="feed-issue-id">#${issue.IssueID}</span></td>
      <td class="dev-name">${issue.Title}</td>
      <td>${issue.Type || 'Bug'}</td>
      <td><span style="color:${pColor};font-weight:600">${issue.Priority}</span></td>
      <td><span style="color:${sColor};font-weight:500">${issue.Status}</span></td>
      <td>${due}</td>
      <td>${issue.ProjectID}</td>
      <td>${issue.ReporterID}</td>`;
    tr.addEventListener('click', () => openStatusModal(issue.IssueID, {
      IssueID: issue.IssueID, IssueTitle: issue.Title,
      ProjectName: 'Project ' + issue.ProjectID, NewStatus: issue.Status
    }));
    issuesBody.appendChild(tr);
  });
}

// ─── Render: Projects Table ─────────────────────────────────
function renderProjectsTable(data) {
  projectsBody.innerHTML = '';
  if (!data || !data.length) {
    projectsBody.innerHTML = '<tr><td colspan="6" style="text-align:center;color:var(--text-muted);padding:2rem;">No projects found</td></tr>';
    return;
  }
  data.forEach(proj => {
    const sColor = {Active:'var(--green)','On Hold':'var(--orange)',Completed:'var(--cyan)',Archived:'var(--text-muted)'}[proj.Status] || 'var(--text-secondary)';
    const start = proj.StartDate ? new Date(proj.StartDate).toLocaleDateString('en-US',{month:'short',day:'numeric',year:'numeric'}) : '—';
    const end = proj.EndDate ? new Date(proj.EndDate).toLocaleDateString('en-US',{month:'short',day:'numeric',year:'numeric'}) : '—';
    const tr = document.createElement('tr');
    tr.style.cursor = 'pointer';
    tr.innerHTML = `
      <td><span class="feed-issue-id">#${proj.ProjectID}</span></td>
      <td class="dev-name">${proj.Name}</td>
      <td>${proj.Description || '—'}</td>
      <td>${start}</td>
      <td>${end}</td>
      <td><span style="color:${sColor};font-weight:600">${proj.Status}</span></td>`;
    tr.addEventListener('click', () => openProjectModal(proj.ProjectID, proj.Name, proj.Status));
    projectsBody.appendChild(tr);
  });
}

// ─── Timestamp ──────────────────────────────────────────────
function updateTimestamp() {
  const ts = new Date().toLocaleTimeString('en-US', { hour:'2-digit', minute:'2-digit', second:'2-digit', hour12:false });
  lastUpdated.querySelector('span').textContent = ts;
}

// ─── Data Loaders ───────────────────────────────────────────
async function loadDashboard() {
  const [projects, workload, activity] = await Promise.all([
    fetchData('/api/dashboard/project-stats', 'projectStats'),
    fetchData('/api/dashboard/developer-workload', 'devWorkload'),
    fetchData('/api/dashboard/recent-activity', 'recentActivity'),
  ]);
  renderProjectCards(projects);
  renderWorkload(workload);
  renderActivityFeed(activity);
  updateTimestamp();
}

async function loadIssues() {
  const data = await fetchData('/api/issues', 'issues');
  renderIssuesTable(data);
}

async function loadProjects() {
  const data = await fetchData('/api/projects', 'projects');
  renderProjectsTable(data);
}

// ─── Refresh Buttons ────────────────────────────────────────
function spinRefresh(btn, loadFn) {
  btn.querySelector('i').style.animation = 'spin 0.6s ease';
  loadFn();
  setTimeout(() => btn.querySelector('i').style.animation = '', 700);
}
refreshBtn.addEventListener('click', () => spinRefresh(refreshBtn, loadDashboard));
refreshIssBtn.addEventListener('click', () => spinRefresh(refreshIssBtn, loadIssues));
refreshProjBtn.addEventListener('click', () => spinRefresh(refreshProjBtn, loadProjects));

// ─── Issue Status Modal ─────────────────────────────────────
function openStatusModal(issueId, data) {
  activeIssueId = issueId;
  statusResp.style.display = 'none';
  statusForm.reset();
  modalInfo.innerHTML = data
    ? `<strong>Issue #${issueId}</strong> — ${data.IssueTitle}<br><span style="color:var(--text-muted)">Project: ${data.ProjectName} · Current: ${data.NewStatus}</span>`
    : `<strong>Issue #${issueId}</strong>`;
  statusModal.classList.add('open');
}
function closeStatusModal() { statusModal.classList.remove('open'); activeIssueId = null; }
modalClose.addEventListener('click', closeStatusModal);
modalCancel.addEventListener('click', closeStatusModal);
statusModal.addEventListener('click', e => { if (e.target === statusModal) closeStatusModal(); });

statusForm.addEventListener('submit', async (e) => {
  e.preventDefault();
  if (!activeIssueId) return;
  const userId = parseInt(document.getElementById('statusUserId').value);
  const newStatus = document.getElementById('statusNewStatus').value;
  const btn = document.getElementById('submitStatus');
  try {
    const res = await fetch(`${API_BASE}/api/issues/${activeIssueId}/status`, {
      method: 'PUT', headers: {'Content-Type':'application/json'},
      body: JSON.stringify({ user_id: userId, new_status: newStatus })
    });
    const result = await res.json();
    if (!res.ok) throw new Error(result.detail || 'Request failed');
    showResponse(statusResp, statusRespPre, result, true);
    btn.classList.add('btn-success');
    btn.innerHTML = '<i class="ph ph-check-circle"></i><span>Mutation Applied</span>';
    setTimeout(() => { btn.classList.remove('btn-success'); btn.innerHTML = '<i class="ph ph-lightning"></i><span>Execute Mutation</span>'; }, 2500);
    showToast('Status updated successfully', 'success');
    setTimeout(() => { loadDashboard(); loadIssues(); }, 800);
  } catch (err) {
    showResponse(statusResp, statusRespPre, { error: err.message }, false);
    showToast('Update failed: ' + err.message, 'error');
  }
});

// ─── Project Status Modal ───────────────────────────────────
function openProjectModal(projectId, name, currentStatus) {
  activeProjectId = projectId;
  projStatusResp.style.display = 'none';
  projStatusForm.reset();
  projModalInfo.innerHTML = `<strong>Project #${projectId}</strong> — ${name}<br><span style="color:var(--text-muted)">Current Status: ${currentStatus}</span>`;
  projectModal.classList.add('open');
}
function closeProjectModal() { projectModal.classList.remove('open'); activeProjectId = null; }
projModalClose.addEventListener('click', closeProjectModal);
projModalCancel.addEventListener('click', closeProjectModal);
projectModal.addEventListener('click', e => { if (e.target === projectModal) closeProjectModal(); });

projStatusForm.addEventListener('submit', async (e) => {
  e.preventDefault();
  if (!activeProjectId) return;
  const newStatus = document.getElementById('projNewStatus').value;
  const btn = document.getElementById('submitProjStatus');
  try {
    const res = await fetch(`${API_BASE}/api/projects/${activeProjectId}/status`, {
      method: 'PUT', headers: {'Content-Type':'application/json'},
      body: JSON.stringify({ new_status: newStatus })
    });
    const result = await res.json();
    if (!res.ok) throw new Error(result.detail || 'Request failed');
    showResponse(projStatusResp, projStatusRespPre, result, true);
    btn.classList.add('btn-success');
    btn.innerHTML = '<i class="ph ph-check-circle"></i><span>Updated</span>';
    setTimeout(() => { btn.classList.remove('btn-success'); btn.innerHTML = '<i class="ph ph-lightning"></i><span>Update Status</span>'; }, 2500);
    showToast(`Project ${activeProjectId} status updated`, 'success');
    setTimeout(() => { loadDashboard(); loadProjects(); }, 800);
  } catch (err) {
    showResponse(projStatusResp, projStatusRespPre, { error: err.message }, false);
    showToast('Update failed: ' + err.message, 'error');
  }
});

// ─── Bug Form ───────────────────────────────────────────────
bugForm.addEventListener('submit', async (e) => {
  e.preventDefault();
  const payload = {
    issue_id:    parseInt(document.getElementById('bugIssueId').value),
    title:       document.getElementById('bugTitle').value,
    priority:    document.getElementById('bugPriority').value,
    project_id:  parseInt(document.getElementById('bugProjectId').value),
    reporter_id: parseInt(document.getElementById('bugReporterId').value),
    due_date:    document.getElementById('bugDueDate').value || null,
    severity:    document.getElementById('bugSeverity').value,
  };
  const btn = document.getElementById('submitBug');
  try {
    const res = await fetch(`${API_BASE}/api/bugs/`, {
      method: 'POST', headers: {'Content-Type':'application/json'},
      body: JSON.stringify(payload)
    });
    const result = await res.json();
    if (!res.ok) throw new Error(result.detail || 'Request failed');
    showResponse(bugResp, bugRespPre, result, true);
    btn.classList.add('btn-success');
    btn.innerHTML = '<i class="ph ph-check-circle"></i><span>Anomaly Logged</span>';
    setTimeout(() => { btn.classList.remove('btn-success'); btn.innerHTML = '<i class="ph ph-paper-plane-tilt"></i><span>Submit Anomaly</span>'; }, 2500);
    showToast('Bug reported successfully — check Issue Registry', 'success');
    // Auto-refresh issues so the new bug shows up immediately
    setTimeout(() => { loadDashboard(); loadIssues(); }, 800);
  } catch (err) {
    showResponse(bugResp, bugRespPre, { error: err.message }, false);
    showToast('Submission failed: ' + err.message, 'error');
  }
});

// ─── Project Create Form ────────────────────────────────────
projectForm.addEventListener('submit', async (e) => {
  e.preventDefault();
  const payload = {
    project_id:  parseInt(document.getElementById('projId').value),
    name:        document.getElementById('projName').value,
    description: document.getElementById('projDesc').value || null,
    start_date:  document.getElementById('projStartDate').value,
    status:      document.getElementById('projFormStatus').value,
  };
  const btn = document.getElementById('submitProject');
  try {
    const res = await fetch(`${API_BASE}/api/projects/`, {
      method: 'POST', headers: {'Content-Type':'application/json'},
      body: JSON.stringify(payload)
    });
    const result = await res.json();
    if (!res.ok) throw new Error(result.detail || 'Request failed');
    showResponse(projResp, projRespPre, result, true);
    btn.classList.add('btn-success');
    btn.innerHTML = '<i class="ph ph-check-circle"></i><span>Project Created</span>';
    setTimeout(() => { btn.classList.remove('btn-success'); btn.innerHTML = '<i class="ph ph-plus"></i><span>Create Project</span>'; }, 2500);
    showToast('Project created successfully', 'success');
    setTimeout(() => { loadProjects(); loadDashboard(); }, 800);
  } catch (err) {
    showResponse(projResp, projRespPre, { error: err.message }, false);
    showToast('Failed: ' + err.message, 'error');
  }
});

// ─── Helpers ────────────────────────────────────────────────
function showResponse(container, pre, data, ok) {
  container.style.display = 'block';
  container.style.borderColor = ok ? 'var(--cyan-dim)' : 'rgba(255,61,90,0.3)';
  container.style.background  = ok ? 'rgba(0,229,255,0.04)' : 'rgba(255,61,90,0.04)';
  pre.style.color = ok ? 'var(--cyan)' : 'var(--red)';
  pre.textContent = JSON.stringify(data, null, 2);
}

function showToast(message, type) {
  const c = document.getElementById('toastContainer');
  const t = document.createElement('div');
  t.className = `toast toast-${type}`;
  t.innerHTML = `<i class="ph ${type==='success'?'ph-check-circle':'ph-warning-circle'}"></i>${message}`;
  c.appendChild(t);
  setTimeout(() => t.remove(), 3600);
}

// ─── Inject spin keyframe ───────────────────────────────────
const s = document.createElement('style');
s.textContent = `@keyframes spin { to { transform: rotate(360deg); } }`;
document.head.appendChild(s);

// ─── Boot ───────────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', () => {
  checkHealth();
  loadDashboard();
});
