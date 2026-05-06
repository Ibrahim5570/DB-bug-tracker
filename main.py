from fastapi import FastAPI, HTTPException, Depends
from pydantic import BaseModel
import pyodbc
from typing import Optional

app = FastAPI(title="BugTracker API", description="FastAPI Backend for SSMS BugTrackerDB")

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
    cursor.execute("SELECT * FROM ISSUE;")
    return fetch_as_dict(cursor)

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
        # pyodbc operates with autocommit=False by default, so we are inherently in a transaction
        
        # We must execute both inserts in a single batch (anonymous block) 
        # so that the TR_Issue_SubtypeEnforce trigger evaluates them together
        # instead of failing after the first statement.
        cursor.execute("""
            BEGIN TRY
                INSERT INTO ISSUE (IssueID, Title, Type, Priority, Status, DueDate, ProjectID, ReporterID)
                VALUES (?, ?, 'Bug', ?, 'Open', ?, ?, ?);
                
                INSERT INTO BUG (IssueID, Severity)
                VALUES (?, ?);
            END TRY
            BEGIN CATCH
                THROW;
            END CATCH
        """, bug.issue_id, bug.title, bug.priority, bug.due_date, bug.project_id, bug.reporter_id, bug.issue_id, bug.severity)
        
        # Step 3: Commit the transaction. The trigger evaluates upon commit.
        conn.commit()
        return {"message": "Bug created successfully."}
        
    except pyodbc.Error as e:
        conn.rollback()
        raise HTTPException(status_code=400, detail=f"Database transaction failed: {str(e)}")