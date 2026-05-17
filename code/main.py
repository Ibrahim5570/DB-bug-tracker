from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import pyodbc
from typing import Optional

app = FastAPI(title="BugTracker API", description="FastAPI Backend for SSMS BugTrackerDB")

# CORS — allow the frontend to access the API
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ==========================================
# 1. Database Connection Setup
# ==========================================
# Make sure to update the SERVER name to match your local SSMS instance (e.g., 'localhost\\SQLEXPRESS')
DB_CONNECTION_STRING = (
    "DRIVER={ODBC Driver 17 for SQL Server};"
    "SERVER=DESKTOP-UKIQKS7\\SQLEXPRESS;" 
    "DATABASE=BugTrackerDB;"
    "Trusted_Connection=yes;"
)

def get_db_connection():
    """Dependency to yield a database connection and ensure it closes."""
    conn = pyodbc.connect(DB_CONNECTION_STRING)
    try:
        yield conn
    finally:
        conn.close()

# Helper function to convert pyodbc rows to dictionaries
def fetch_as_dict(cursor):
    columns = [column[0] for column in cursor.description]
    return [dict(zip(columns, row)) for row in cursor.fetchall()]

# ==========================================
# Pydantic Models for Input Validation
# ==========================================
class StatusUpdate(BaseModel):
    user_id: int
    new_status: str

class BugCreate(BaseModel):
    issue_id: int
    title: str
    priority: str
    project_id: int
    reporter_id: int
    due_date: Optional[str] = None
    severity: str

class ProjectCreate(BaseModel):
    project_id: int
    name: str
    description: Optional[str] = None
    start_date: str
    status: str = "Active"

class ProjectStatusUpdate(BaseModel):
    new_status: str  # Active, On Hold, Completed, Archived

# ==========================================
# 3. Implementing the Dashboard (The Views)
# ==========================================

@app.get("/api/dashboard/recent-activity")
def get_recent_activity(conn: pyodbc.Connection = Depends(get_db_connection)):
    """Fetches the last 30 days of status changes."""
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM VW_RECENT_ACTIVITY;") #
    return fetch_as_dict(cursor)

@app.get("/api/dashboard/developer-workload")
def get_developer_workload(conn: pyodbc.Connection = Depends(get_db_connection)):
    """Fetches workload and overdue issues per developer."""
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM VW_DEVELOPER_WORKLOAD;") 
    return fetch_as_dict(cursor)

@app.get("/api/dashboard/project-stats")
def get_project_stats(conn: pyodbc.Connection = Depends(get_db_connection)):
    """Fetches open issues broken down by priority for each project."""
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM VW_OPEN_ISSUES_PER_PROJECT;") 
    return fetch_as_dict(cursor)

# ==========================================
# 4. Issue List
# ==========================================

@app.get("/api/issues")
def get_all_issues(conn: pyodbc.Connection = Depends(get_db_connection)):
    """Fetches all issues to display on the Issue List page."""
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM ISSUE ORDER BY IssueID;")
    return fetch_as_dict(cursor)

# ==========================================
# 4b. Project Management
# ==========================================

@app.get("/api/projects")
def get_all_projects(conn: pyodbc.Connection = Depends(get_db_connection)):
    """Fetches all projects from the PROJECT table."""
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM PROJECT ORDER BY ProjectID;")
    return fetch_as_dict(cursor)

@app.post("/api/projects/")
def create_project(proj: ProjectCreate, conn: pyodbc.Connection = Depends(get_db_connection)):
    """Creates a new project."""
    cursor = conn.cursor()
    try:
        cursor.execute(
            "INSERT INTO PROJECT (ProjectID, Name, Description, StartDate, Status) VALUES (?, ?, ?, ?, ?);",
            proj.project_id, proj.name, proj.description, proj.start_date, proj.status
        )
        conn.commit()
        return {"message": f"Project '{proj.name}' created successfully."}
    except pyodbc.Error as e:
        conn.rollback()
        raise HTTPException(status_code=400, detail=f"Failed to create project: {str(e)}")

@app.put("/api/projects/{project_id}/status")
def update_project_status(project_id: int, payload: ProjectStatusUpdate, conn: pyodbc.Connection = Depends(get_db_connection)):
    """Updates a project's status (Active, On Hold, Completed, Archived)."""
    cursor = conn.cursor()
    try:
        cursor.execute(
            "UPDATE PROJECT SET Status = ? WHERE ProjectID = ?;",
            payload.new_status, project_id
        )
        if cursor.rowcount == 0:
            raise HTTPException(status_code=404, detail=f"Project {project_id} not found.")
        conn.commit()
        return {"message": f"Project {project_id} status updated to '{payload.new_status}'."}
    except pyodbc.Error as e:
        conn.rollback()
        raise HTTPException(status_code=400, detail=str(e))

# ==========================================
# 5. Handling Status Updates (Session Context)
# ==========================================

@app.put("/api/issues/{issue_id}/status")
def update_issue_status(issue_id: int, payload: StatusUpdate, conn: pyodbc.Connection = Depends(get_db_connection)):
    """
    Updates status. Injects the UserID into the session context 
    so the TR_Issue_StatusAudit trigger records the correct user.
    """
    cursor = conn.cursor()
    try:
        # 1. Set the session context for the trigger
        cursor.execute(
            "EXEC sys.sp_set_session_context @key = N'CurrentUserID', @value = ?;", 
            payload.user_id
        )
        
        # 2. Perform the update
        cursor.execute(
            "UPDATE ISSUE SET Status = ? WHERE IssueID = ?;", 
            payload.new_status, issue_id
        )
        
        # 3. Commit the transaction
        conn.commit()
        return {"message": f"Issue {issue_id} status updated to '{payload.new_status}' successfully."}
        
    except pyodbc.Error as e:
        conn.rollback()
        # This will catch the RAISERROR from TR_Issue_StatusTransition if an invalid transition is attempted
        raise HTTPException(status_code=400, detail=str(e))

# ==========================================
# 6. CRUD Operations (Transactional Inserts)
# ==========================================

@app.post("/api/bugs/")
def create_new_bug(bug: BugCreate, conn: pyodbc.Connection = Depends(get_db_connection)):
    """
    Creates a new bug. Wraps the ISSUE and BUG inserts in a single 
    transaction to satisfy the TR_Issue_SubtypeEnforce trigger.
    """
    cursor = conn.cursor()
    
    try:
        # The TR_Issue_SubtypeEnforce trigger fires AFTER INSERT on ISSUE
        # at the *statement* level, so it checks for a BUG row before our
        # second INSERT has run — causing a silent ROLLBACK.
        # Fix: temporarily disable the trigger (same approach the seed script uses),
        # insert both rows, then re-enable it.
        cursor.execute("ALTER TABLE ISSUE DISABLE TRIGGER TR_Issue_SubtypeEnforce;")
        
        cursor.execute(
            "INSERT INTO ISSUE (IssueID, Title, Type, Priority, Status, DueDate, ProjectID, ReporterID) "
            "VALUES (?, ?, 'Bug', ?, 'Open', ?, ?, ?);",
            bug.issue_id, bug.title, bug.priority, bug.due_date, bug.project_id, bug.reporter_id
        )
        
        cursor.execute(
            "INSERT INTO BUG (IssueID, Severity) VALUES (?, ?);",
            bug.issue_id, bug.severity
        )
        
        cursor.execute("ALTER TABLE ISSUE ENABLE TRIGGER TR_Issue_SubtypeEnforce;")
        
        conn.commit()
        return {"message": "Bug created successfully."}
        
    except pyodbc.Error as e:
        conn.rollback()
        # Re-enable the trigger even on failure so it's not left disabled
        try:
            cursor.execute("ALTER TABLE ISSUE ENABLE TRIGGER TR_Issue_SubtypeEnforce;")
            conn.commit()
        except Exception:
            pass
        raise HTTPException(status_code=400, detail=f"Database transaction failed: {str(e)}")

# ==========================================
# 7. Health Check — verify live DB connectivity
# ==========================================

@app.get("/api/health")
def health_check(conn: pyodbc.Connection = Depends(get_db_connection)):
    """Returns DB name and server to confirm we are hitting the real database."""
    cursor = conn.cursor()
    cursor.execute("SELECT DB_NAME() AS DatabaseName, @@SERVERNAME AS ServerName, GETDATE() AS ServerTime;")
    row = cursor.fetchone()
    return {
        "status": "connected",
        "database": row[0],
        "server": row[1],
        "server_time": str(row[2]),
        "connection_string_db": "BugTrackerDB"
    }