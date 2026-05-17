import pyodbc

DB_CONNECTION_STRING = (
    "DRIVER={ODBC Driver 17 for SQL Server};"
    "SERVER=localhost;" 
    "DATABASE=BugTrackerDB;"
    "Trusted_Connection=yes;"
)

def test():
    conn = pyodbc.connect(DB_CONNECTION_STRING)
    cursor = conn.cursor()
    try:
        # Let's insert a fake issue to test if batch works
        cursor.execute("""
            INSERT INTO ISSUE (IssueID, Title, Type, Priority, Status, DueDate, ProjectID, ReporterID)
            VALUES (999, 'Test batch', 'Bug', 'Low', 'Open', '2026-12-31', 1, 1);
            
            INSERT INTO BUG (IssueID, Severity)
            VALUES (999, 'Minor');
        """)
        conn.commit()
        print("Batch insert worked!")
    except Exception as e:
        print("Batch insert failed:", e)
        conn.rollback()

if __name__ == '__main__':
    test()
