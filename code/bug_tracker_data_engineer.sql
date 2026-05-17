-- ============================================================
--  BUG TRACKER  --  Data Engineer Deliverable
--  Ibrahim (The Data Engineer)
--  SQL Server (T-SQL)
-- ============================================================
--  Sections
--    1.  Database & Schema Setup
--    2.  DDL  --  CREATE TABLE (all 16 tables, PK / FK / CHECK)
--    3.  Enhancements A  --  Indexes
--    4.  Enhancements B  --  Dashboard Views
--    5.  Trigger  --  Status Audit History (auto-populates STATUS_HISTORY)
-- ============================================================

-- ============================================================
-- SECTION 1: DATABASE & SCHEMA SETUP
-- ============================================================

USE master;
GO

IF DB_ID('BugTrackerDB') IS NOT NULL
    DROP DATABASE BugTrackerDB;
GO

CREATE DATABASE BugTrackerDB;
GO

USE BugTrackerDB;
GO

-- ============================================================
-- SECTION 2: DDL — CREATE TABLES
-- ============================================================
-- Order respects FK dependencies (parents before children).
-- ============================================================

-- ----------------------------------------------------------
-- 2.01  USERS
--       (named USERS to avoid conflict with SQL Server
--        reserved word USER)
-- ----------------------------------------------------------
CREATE TABLE USERS (
    UserID      INT             CONSTRAINT PK_Users PRIMARY KEY,
    FirstName   VARCHAR(60)     NOT NULL,
    LastName    VARCHAR(60)     NOT NULL,
    Email       VARCHAR(120)    NOT NULL
                    CONSTRAINT UQ_Users_Email UNIQUE,
    Role        VARCHAR(30)     NOT NULL
                    CONSTRAINT CK_Users_Role
                    CHECK (Role IN ('Admin', 'Developer', 'QA', 'Manager', 'Viewer')),
    JoinDate    DATE            NOT NULL DEFAULT CAST(GETDATE() AS DATE)
);
GO

-- ----------------------------------------------------------
-- 2.02  USER_PHONE
--       Multi-valued attribute — one user can have many phones
-- ----------------------------------------------------------
CREATE TABLE USER_PHONE (
    UserID      INT             NOT NULL,
    PhoneNumber VARCHAR(20)     NOT NULL,
    CONSTRAINT PK_UserPhone PRIMARY KEY (UserID, PhoneNumber),
    CONSTRAINT FK_UserPhone_Users
        FOREIGN KEY (UserID) REFERENCES USERS (UserID)
        ON DELETE CASCADE
);
GO

-- ----------------------------------------------------------
-- 2.03  PROJECT
-- ----------------------------------------------------------
CREATE TABLE PROJECT (
    ProjectID   INT             CONSTRAINT PK_Project PRIMARY KEY,
    Name        VARCHAR(150)    NOT NULL,
    Description VARCHAR(MAX)    NULL,
    StartDate   DATE            NOT NULL,
    EndDate     DATE            NULL,
    Status      VARCHAR(20)     NOT NULL DEFAULT 'Active'
                    CONSTRAINT CK_Project_Status
                    CHECK (Status IN ('Active', 'On Hold', 'Completed', 'Archived')),
    CONSTRAINT CK_Project_Dates
        CHECK (EndDate IS NULL OR EndDate >= StartDate)
);
GO

-- ----------------------------------------------------------
-- 2.04  PROJECT_MEMBER  (many-to-many junction: PROJECT × USER)
--       Business rule: every project must have exactly one
--       member with MemberRole = 'Manager'.
--       (Enforced by trigger TR_ProjectMember_MandatoryManager
--        defined in Section 5.)
-- ----------------------------------------------------------
CREATE TABLE PROJECT_MEMBER (
    ProjectID   INT             NOT NULL,
    UserID      INT             NOT NULL,
    MemberRole  VARCHAR(30)     NOT NULL
                    CONSTRAINT CK_PM_Role
                    CHECK (MemberRole IN ('Manager', 'Developer', 'QA', 'Viewer')),
    JoinedAt    DATETIME        NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_ProjectMember PRIMARY KEY (ProjectID, UserID),
    CONSTRAINT FK_PM_Project
        FOREIGN KEY (ProjectID) REFERENCES PROJECT (ProjectID)
        ON DELETE CASCADE,
    CONSTRAINT FK_PM_Users
        FOREIGN KEY (UserID) REFERENCES USERS (UserID)
        ON DELETE CASCADE
);
GO

-- ----------------------------------------------------------
-- 2.05  SPRINT
-- ----------------------------------------------------------
CREATE TABLE SPRINT (
    SprintID    INT             CONSTRAINT PK_Sprint PRIMARY KEY,
    Name        VARCHAR(100)    NOT NULL,
    StartDate   DATE            NOT NULL,
    EndDate     DATE            NOT NULL,
    Goal        VARCHAR(500)    NULL,
    Status      VARCHAR(20)     NOT NULL DEFAULT 'Planning'
                    CONSTRAINT CK_Sprint_Status
                    CHECK (Status IN ('Planning', 'Active', 'Completed', 'Cancelled')),
    ProjectID   INT             NOT NULL,
    CONSTRAINT FK_Sprint_Project
        FOREIGN KEY (ProjectID) REFERENCES PROJECT (ProjectID)
        ON DELETE CASCADE,
    CONSTRAINT CK_Sprint_Dates
        CHECK (EndDate >= StartDate)
);
GO

-- ----------------------------------------------------------
-- 2.06  LABEL
-- ----------------------------------------------------------
CREATE TABLE LABEL (
    LabelID     INT             CONSTRAINT PK_Label PRIMARY KEY,
    Name        VARCHAR(60)     NOT NULL
                    CONSTRAINT UQ_Label_Name UNIQUE,
    Color       CHAR(7)         NULL           -- e.g. '#FF5733'
                    CONSTRAINT CK_Label_Color
                    CHECK (Color IS NULL OR Color LIKE '#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]')
);
GO

-- ----------------------------------------------------------
-- 2.07  ISSUE  (supertype)
--       Status transition rules are enforced by
--       TR_Issue_StatusTransition (Section 5).
-- ----------------------------------------------------------
CREATE TABLE ISSUE (
    IssueID         INT             CONSTRAINT PK_Issue PRIMARY KEY,
    Title           VARCHAR(255)    NOT NULL,
    Type            VARCHAR(10)     NOT NULL
                        CONSTRAINT CK_Issue_Type
                        CHECK (Type IN ('Bug', 'Feature', 'Task')),
    Priority        VARCHAR(10)     NOT NULL
                        CONSTRAINT CK_Issue_Priority
                        CHECK (Priority IN ('Low', 'Medium', 'High', 'Critical')),
    Status          VARCHAR(15)     NOT NULL DEFAULT 'Open'
                        CONSTRAINT CK_Issue_Status
                        CHECK (Status IN ('Open', 'In Progress', 'In Review', 'Done', 'Closed', 'Rejected')),
    DueDate         DATE            NULL,
    CreatedAt       DATETIME        NOT NULL DEFAULT GETDATE(),
    ResolutionTime  AS (
        CASE WHEN Status IN ('Done','Closed')
             THEN DATEDIFF(HOUR, CreatedAt, GETDATE())
             ELSE NULL
        END),                              -- derived (computed column)
    ProjectID       INT             NOT NULL,
    ReporterID      INT             NOT NULL,
    CONSTRAINT FK_Issue_Project
        FOREIGN KEY (ProjectID) REFERENCES PROJECT (ProjectID),
    CONSTRAINT FK_Issue_Reporter
        FOREIGN KEY (ReporterID) REFERENCES USERS (UserID)
);
GO

-- ----------------------------------------------------------
-- 2.08  BUG  (subtype — ISA, shares PK with ISSUE)
-- ----------------------------------------------------------
CREATE TABLE BUG (
    IssueID             INT             CONSTRAINT PK_Bug PRIMARY KEY,
    Severity            VARCHAR(10)     NOT NULL
                            CONSTRAINT CK_Bug_Severity
                            CHECK (Severity IN ('Trivial', 'Minor', 'Major', 'Critical', 'Blocker')),
    StepsToReproduce    VARCHAR(MAX)    NULL,
    CONSTRAINT FK_Bug_Issue
        FOREIGN KEY (IssueID) REFERENCES ISSUE (IssueID)
        ON DELETE CASCADE,
    CONSTRAINT CK_Bug_TypeMatch
        CHECK (1 = 1)   -- Type correctness enforced by TR_Issue_SubtypeEnforce
);
GO

-- ----------------------------------------------------------
-- 2.09  FEATURE  (subtype)
-- ----------------------------------------------------------
CREATE TABLE FEATURE (
    IssueID         INT             CONSTRAINT PK_Feature PRIMARY KEY,
    BusinessValue   INT             NULL
                        CONSTRAINT CK_Feature_BusinessValue
                        CHECK (BusinessValue IS NULL OR (BusinessValue BETWEEN 1 AND 10)),
    AffectedModule  VARCHAR(100)    NULL,
    CONSTRAINT FK_Feature_Issue
        FOREIGN KEY (IssueID) REFERENCES ISSUE (IssueID)
        ON DELETE CASCADE
);
GO

-- ----------------------------------------------------------
-- 2.10  TASK  (subtype)
-- ----------------------------------------------------------
CREATE TABLE TASK (
    IssueID         INT             CONSTRAINT PK_Task PRIMARY KEY,
    EstimatedHours  DECIMAL(6,2)    NULL
                        CONSTRAINT CK_Task_Hours
                        CHECK (EstimatedHours IS NULL OR EstimatedHours > 0),
    TaskType        VARCHAR(30)     NULL
                        CONSTRAINT CK_Task_TaskType
                        CHECK (TaskType IN ('Documentation', 'Testing', 'DevOps',
                                            'Research', 'Refactoring', 'Other', NULL)),
    CONSTRAINT FK_Task_Issue
        FOREIGN KEY (IssueID) REFERENCES ISSUE (IssueID)
        ON DELETE CASCADE
);
GO

-- ----------------------------------------------------------
-- 2.11  ISSUE_ASSIGNMENT  (many-to-many junction: ISSUE × USER)
-- ----------------------------------------------------------
CREATE TABLE ISSUE_ASSIGNMENT (
    IssueID     INT             NOT NULL,
    UserID      INT             NOT NULL,
    AssignedAt  DATETIME        NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_IssueAssignment PRIMARY KEY (IssueID, UserID),
    CONSTRAINT FK_IA_Issue
        FOREIGN KEY (IssueID) REFERENCES ISSUE (IssueID)
        ON DELETE CASCADE,
    CONSTRAINT FK_IA_Users
        FOREIGN KEY (UserID) REFERENCES USERS (UserID)
        ON DELETE CASCADE
);
GO

-- ----------------------------------------------------------
-- 2.12  SPRINT_ISSUE  (many-to-many junction: SPRINT × ISSUE)
-- ----------------------------------------------------------
CREATE TABLE SPRINT_ISSUE (
    SprintID    INT             NOT NULL,
    IssueID     INT             NOT NULL,
    CONSTRAINT PK_SprintIssue PRIMARY KEY (SprintID, IssueID),
    CONSTRAINT FK_SI_Sprint
        FOREIGN KEY (SprintID) REFERENCES SPRINT (SprintID)
        ON DELETE CASCADE,
    CONSTRAINT FK_SI_Issue
        FOREIGN KEY (IssueID) REFERENCES ISSUE (IssueID)
        ON DELETE CASCADE
);
GO

-- ----------------------------------------------------------
-- 2.13  COMMENT  (weak entity — identifying owner is ISSUE)
--       Composite PK: (CommentNo, IssueID)
--       CommentNo is the partial key (auto-numbered per issue)
-- ----------------------------------------------------------
CREATE TABLE COMMENT (
    CommentNo   INT             NOT NULL,
    IssueID     INT             NOT NULL,
    AuthorID    INT             NOT NULL,
    Content     VARCHAR(MAX)    NOT NULL,
    Timestamp   DATETIME        NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_Comment PRIMARY KEY (CommentNo, IssueID),
    CONSTRAINT FK_Comment_Issue
        FOREIGN KEY (IssueID) REFERENCES ISSUE (IssueID)
        ON DELETE CASCADE,
    CONSTRAINT FK_Comment_Author
        FOREIGN KEY (AuthorID) REFERENCES USERS (UserID)
);
GO

-- ----------------------------------------------------------
-- 2.14  ISSUE_LABEL  (many-to-many junction: ISSUE × LABEL)
-- ----------------------------------------------------------
CREATE TABLE ISSUE_LABEL (
    IssueID     INT             NOT NULL,
    LabelID     INT             NOT NULL,
    CONSTRAINT PK_IssueLabel PRIMARY KEY (IssueID, LabelID),
    CONSTRAINT FK_IL_Issue
        FOREIGN KEY (IssueID) REFERENCES ISSUE (IssueID)
        ON DELETE CASCADE,
    CONSTRAINT FK_IL_Label
        FOREIGN KEY (LabelID) REFERENCES LABEL (LabelID)
        ON DELETE CASCADE
);
GO

-- ----------------------------------------------------------
-- 2.15  ATTACHMENT
-- ----------------------------------------------------------
CREATE TABLE ATTACHMENT (
    AttachID    INT             CONSTRAINT PK_Attachment PRIMARY KEY,
    IssueID     INT             NOT NULL,
    FileName    VARCHAR(260)    NULL,
    URL         VARCHAR(500)    NOT NULL,
    UploadedAt  DATETIME        NOT NULL DEFAULT GETDATE(),
    UploaderID  INT             NOT NULL,
    CONSTRAINT FK_Attach_Issue
        FOREIGN KEY (IssueID) REFERENCES ISSUE (IssueID)
        ON DELETE CASCADE,
    CONSTRAINT FK_Attach_Uploader
        FOREIGN KEY (UploaderID) REFERENCES USERS (UserID)
);
GO

-- ----------------------------------------------------------
-- 2.16  STATUS_HISTORY
--       Auto-populated by TR_Issue_StatusAudit (Section 5).
--       Can also be inserted manually for seeding.
-- ----------------------------------------------------------
CREATE TABLE STATUS_HISTORY (
    HistoryID   INT             IDENTITY(1,1) CONSTRAINT PK_StatusHistory PRIMARY KEY,
    IssueID     INT             NOT NULL,
    ChangedBy   INT             NOT NULL,           -- UserID
    OldStatus   VARCHAR(15)     NULL,               -- NULL for initial creation
    NewStatus   VARCHAR(15)     NOT NULL,
    ChangedAt   DATETIME        NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_SH_Issue
        FOREIGN KEY (IssueID) REFERENCES ISSUE (IssueID)
        ON DELETE CASCADE,
    CONSTRAINT FK_SH_ChangedBy
        FOREIGN KEY (ChangedBy) REFERENCES USERS (UserID)
);
GO


-- ============================================================
-- SECTION 3: ENHANCEMENTS A — INDEXES
-- ============================================================
-- Strategy: cover the query patterns described in the project:
--   • Filtering issues by project, status, priority, type
--   • Searching by assignee (workload dashboard)
--   • Sprint velocity queries (sprint + status)
--   • Audit history lookups by issue
-- ============================================================

-- 3.01  ISSUE — most frequently filtered columns
--       Composite index: (ProjectID, Status) covers the
--       "all open issues in a project" query with one seek.
CREATE NONCLUSTERED INDEX IX_Issue_Project_Status
    ON ISSUE (ProjectID, Status)
    INCLUDE (Title, Priority, Type, DueDate, ReporterID);
GO

-- 3.02  ISSUE — priority-based dashboards (e.g. Critical first)
CREATE NONCLUSTERED INDEX IX_Issue_Priority
    ON ISSUE (Priority, Status)
    INCLUDE (IssueID, Title, ProjectID);
GO

-- 3.03  ISSUE — type-based filtering (Bug / Feature / Task counts)
CREATE NONCLUSTERED INDEX IX_Issue_Type_Status
    ON ISSUE (Type, Status);
GO

-- 3.04  ISSUE_ASSIGNMENT — "what is this developer working on?"
--       Supports the developer workload view.
CREATE NONCLUSTERED INDEX IX_IssueAssignment_UserID
    ON ISSUE_ASSIGNMENT (UserID)
    INCLUDE (IssueID, AssignedAt);
GO

-- 3.05  SPRINT_ISSUE — sprint velocity: quickly resolve all
--       issues belonging to a sprint
CREATE NONCLUSTERED INDEX IX_SprintIssue_SprintID
    ON SPRINT_ISSUE (SprintID)
    INCLUDE (IssueID);
GO

-- 3.06  SPRINT — per-project sprint lookup
CREATE NONCLUSTERED INDEX IX_Sprint_Project_Status
    ON SPRINT (ProjectID, Status)
    INCLUDE (SprintID, Name, StartDate, EndDate);
GO

-- 3.07  STATUS_HISTORY — audit trail per issue (time-ordered)
CREATE NONCLUSTERED INDEX IX_StatusHistory_Issue_Time
    ON STATUS_HISTORY (IssueID, ChangedAt DESC)
    INCLUDE (OldStatus, NewStatus, ChangedBy);
GO

-- 3.08  COMMENT — "all comments on an issue" ordered by time
CREATE NONCLUSTERED INDEX IX_Comment_Issue_Time
    ON COMMENT (IssueID, Timestamp ASC)
    INCLUDE (CommentNo, AuthorID);
GO

-- 3.09  USERS — email lookup (login / search)
CREATE NONCLUSTERED INDEX IX_Users_Email
    ON USERS (Email)
    INCLUDE (FirstName, LastName, Role);
GO

-- 3.10  PROJECT_MEMBER — "which projects does a user manage?"
CREATE NONCLUSTERED INDEX IX_PM_UserID_Role
    ON PROJECT_MEMBER (UserID, MemberRole)
    INCLUDE (ProjectID, JoinedAt);
GO


-- ============================================================
-- SECTION 4: ENHANCEMENTS B — DASHBOARD VIEWS
-- ============================================================

-- ----------------------------------------------------------
-- 4.01  VW_OPEN_ISSUES_PER_PROJECT
--       Shows every project with a count of its open issues
--       broken down by priority — feeds the project manager
--       overview panel.
-- ----------------------------------------------------------
CREATE OR ALTER VIEW VW_OPEN_ISSUES_PER_PROJECT AS
    SELECT
        P.ProjectID,
        P.Name                              AS ProjectName,
        P.Status                            AS ProjectStatus,
        COUNT(I.IssueID)                    AS TotalOpenIssues,
        SUM(CASE WHEN I.Priority = 'Critical' THEN 1 ELSE 0 END) AS Critical,
        SUM(CASE WHEN I.Priority = 'High'     THEN 1 ELSE 0 END) AS High,
        SUM(CASE WHEN I.Priority = 'Medium'   THEN 1 ELSE 0 END) AS Medium,
        SUM(CASE WHEN I.Priority = 'Low'      THEN 1 ELSE 0 END) AS Low
    FROM PROJECT AS P
    LEFT JOIN ISSUE AS I
        ON I.ProjectID = P.ProjectID
       AND I.Status NOT IN ('Done', 'Closed', 'Rejected')
    GROUP BY P.ProjectID, P.Name, P.Status;
GO

-- ----------------------------------------------------------
-- 4.02  VW_DEVELOPER_WORKLOAD
--       For each user with at least one active assignment,
--       shows how many issues they own and how many are
--       overdue — feeds the workload / capacity dashboard.
-- ----------------------------------------------------------
CREATE OR ALTER VIEW VW_DEVELOPER_WORKLOAD AS
    SELECT
        U.UserID,
        U.FirstName + ' ' + U.LastName     AS DeveloperName,
        U.Role,
        COUNT(IA.IssueID)                  AS TotalAssigned,
        SUM(CASE WHEN I.Status NOT IN ('Done','Closed','Rejected')
                 THEN 1 ELSE 0 END)        AS ActiveIssues,
        SUM(CASE WHEN I.Status NOT IN ('Done','Closed','Rejected')
                  AND I.DueDate < CAST(GETDATE() AS DATE)
                 THEN 1 ELSE 0 END)        AS OverdueIssues,
        SUM(CASE WHEN I.Status = 'Done'    THEN 1 ELSE 0 END) AS Resolved
    FROM USERS AS U
    JOIN ISSUE_ASSIGNMENT AS IA ON IA.UserID = U.UserID
    JOIN ISSUE            AS I  ON I.IssueID = IA.IssueID
    GROUP BY U.UserID, U.FirstName, U.LastName, U.Role;
GO

-- ----------------------------------------------------------
-- 4.03  VW_SPRINT_VELOCITY
--       Per sprint: total issues, done, incomplete, and a
--       velocity % — feeds the sprint progress bar.
-- ----------------------------------------------------------
CREATE OR ALTER VIEW VW_SPRINT_VELOCITY AS
    SELECT
        S.SprintID,
        S.Name                              AS SprintName,
        P.Name                              AS ProjectName,
        S.StartDate,
        S.EndDate,
        S.Status                            AS SprintStatus,
        COUNT(SI.IssueID)                   AS TotalIssues,
        SUM(CASE WHEN I.Status IN ('Done','Closed') THEN 1 ELSE 0 END) AS CompletedIssues,
        SUM(CASE WHEN I.Status NOT IN ('Done','Closed','Rejected')
                 THEN 1 ELSE 0 END)         AS RemainingIssues,
        CASE
            WHEN COUNT(SI.IssueID) = 0 THEN 0
            ELSE CAST(
                    SUM(CASE WHEN I.Status IN ('Done','Closed') THEN 1 ELSE 0 END)
                  * 100.0
                  / COUNT(SI.IssueID)
                 AS DECIMAL(5,2))
        END                                 AS VelocityPct
    FROM SPRINT  AS S
    JOIN PROJECT AS P  ON P.ProjectID = S.ProjectID
    LEFT JOIN SPRINT_ISSUE AS SI ON SI.SprintID = S.SprintID
    LEFT JOIN ISSUE        AS I  ON I.IssueID   = SI.IssueID
    GROUP BY S.SprintID, S.Name, P.Name, S.StartDate, S.EndDate, S.Status;
GO

-- ----------------------------------------------------------
-- 4.04  VW_BUG_SEVERITY_BREAKDOWN
--       Per project, counts bugs grouped by severity —
--       useful for QA dashboard and monthly trend queries.
-- ----------------------------------------------------------
CREATE OR ALTER VIEW VW_BUG_SEVERITY_BREAKDOWN AS
    SELECT
        P.ProjectID,
        P.Name                              AS ProjectName,
        B.Severity,
        COUNT(*)                            AS BugCount,
        SUM(CASE WHEN I.Status IN ('Done','Closed') THEN 1 ELSE 0 END) AS Resolved,
        SUM(CASE WHEN I.Status NOT IN ('Done','Closed','Rejected')
                 THEN 1 ELSE 0 END)         AS Outstanding
    FROM BUG AS B
    JOIN ISSUE   AS I ON I.IssueID   = B.IssueID
    JOIN PROJECT AS P ON P.ProjectID = I.ProjectID
    GROUP BY P.ProjectID, P.Name, B.Severity;
GO

-- ----------------------------------------------------------
-- 4.05  VW_RECENT_ACTIVITY
--       Last 30 days of status changes across the whole
--       system — feeds the activity feed on the dashboard.
-- ----------------------------------------------------------
CREATE OR ALTER VIEW VW_RECENT_ACTIVITY AS
    SELECT
        SH.HistoryID,
        SH.ChangedAt,
        I.IssueID,
        I.Title                             AS IssueTitle,
        I.Type                              AS IssueType,
        P.Name                              AS ProjectName,
        U.FirstName + ' ' + U.LastName     AS ChangedByName,
        SH.OldStatus,
        SH.NewStatus
    FROM STATUS_HISTORY AS SH
    JOIN ISSUE   AS I ON I.IssueID   = SH.IssueID
    JOIN PROJECT AS P ON P.ProjectID = I.ProjectID
    JOIN USERS   AS U ON U.UserID    = SH.ChangedBy
    WHERE SH.ChangedAt >= DATEADD(DAY, -30, GETDATE());
GO


-- ============================================================
-- SECTION 5: TRIGGERS
-- ============================================================

-- ----------------------------------------------------------
-- 5.01  TR_Issue_StatusAudit
--       Fires AFTER UPDATE on ISSUE.Status.
--       Automatically inserts a row into STATUS_HISTORY
--       whenever an issue's status changes.
--
--       NOTE: Because STATUS_HISTORY.ChangedBy requires a
--       UserID, the application must SET the session context
--       before updating:
--           EXEC sys.sp_set_session_context
--               @key = N'CurrentUserID', @value = <userID>;
--       The trigger reads this context value. If absent it
--       falls back to the ReporterID as a safe default.
-- ----------------------------------------------------------
CREATE OR ALTER TRIGGER TR_Issue_StatusAudit
ON ISSUE
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Only proceed if Status actually changed
    IF NOT UPDATE(Status) RETURN;

    -- Identify the acting user from session context (set by app layer)
    DECLARE @ActingUserID INT =
        TRY_CAST(SESSION_CONTEXT(N'CurrentUserID') AS INT);

    INSERT INTO STATUS_HISTORY (IssueID, ChangedBy, OldStatus, NewStatus, ChangedAt)
    SELECT
        i.IssueID,
        ISNULL(@ActingUserID, i.ReporterID),   -- fallback to reporter
        d.Status,                              -- old (from DELETED pseudo-table)
        i.Status,                              -- new (from INSERTED pseudo-table)
        GETDATE()
    FROM INSERTED AS i
    JOIN DELETED  AS d ON d.IssueID = i.IssueID
    WHERE d.Status <> i.Status;               -- guard: only real changes
END;
GO

-- ----------------------------------------------------------
-- 5.02  TR_Issue_StatusTransition
--       Enforces legal status state-machine:
--
--       Open ──► In Progress ──► In Review ──► Done
--          └──────────────────────────────────► Closed
--          └──────────────────────────────────► Rejected
--       (re-open: Done/Closed ──► Open is allowed)
--
--       Any other transition is blocked with RAISERROR.
-- ----------------------------------------------------------
CREATE OR ALTER TRIGGER TR_Issue_StatusTransition
ON ISSUE
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(Status) RETURN;

    IF EXISTS (
        SELECT 1
        FROM INSERTED AS i
        JOIN DELETED  AS d ON d.IssueID = i.IssueID
        WHERE d.Status <> i.Status
          AND (
                -- disallow going backwards deeper than one step
                (d.Status = 'In Progress' AND i.Status = 'Open'         ) OR
                (d.Status = 'In Review'   AND i.Status = 'Open'         ) OR
                (d.Status = 'In Review'   AND i.Status = 'In Progress'  ) OR
                (d.Status = 'Done'        AND i.Status = 'In Progress'  ) OR
                (d.Status = 'Done'        AND i.Status = 'In Review'    ) OR
                (d.Status = 'Rejected'    AND i.Status NOT IN ('Open')  ) OR
                (d.Status = 'Closed'      AND i.Status NOT IN ('Open')  )
              )
    )
    BEGIN
        ROLLBACK TRANSACTION;
        RAISERROR(
            'Invalid status transition. Check the allowed state machine: '
            'Open → In Progress → In Review → Done / Closed / Rejected. '
            'Re-open from Done or Closed is allowed.', 16, 1);
        RETURN;
    END
END;
GO

-- ----------------------------------------------------------
-- 5.03  TR_Comment_AutoNumber
--       Weak entity pattern: CommentNo is a partial key
--       scoped per IssueID. This trigger auto-assigns the
--       next CommentNo within each issue before INSERT.
-- ----------------------------------------------------------
CREATE OR ALTER TRIGGER TR_Comment_AutoNumber
ON COMMENT
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO COMMENT (CommentNo, IssueID, AuthorID, Content, Timestamp)
    SELECT
        ISNULL(
            (SELECT MAX(C.CommentNo)
             FROM   COMMENT AS C
             WHERE  C.IssueID = i.IssueID), 0) + 1,
        i.IssueID,
        i.AuthorID,
        i.Content,
        ISNULL(i.Timestamp, GETDATE())
    FROM INSERTED AS i;
END;
GO

-- ----------------------------------------------------------
-- 5.04  TR_ProjectMember_MandatoryManager
--       Business rule: every project must retain at least
--       one member with MemberRole = 'Manager'.
--       Fires on DELETE and UPDATE of PROJECT_MEMBER.
-- ----------------------------------------------------------
CREATE OR ALTER TRIGGER TR_ProjectMember_MandatoryManager
ON PROJECT_MEMBER
AFTER DELETE, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- For each affected project, check manager still exists
    IF EXISTS (
        SELECT d.ProjectID
        FROM   DELETED AS d
        WHERE  NOT EXISTS (
            SELECT 1
            FROM   PROJECT_MEMBER AS pm
            WHERE  pm.ProjectID  = d.ProjectID
              AND  pm.MemberRole = 'Manager'
        )
    )
    BEGIN
        ROLLBACK TRANSACTION;
        RAISERROR(
            'Business rule violation: each project must have at least one Manager. '
            'Assign a new Manager before removing the current one.', 16, 1);
        RETURN;
    END
END;
GO

-- ----------------------------------------------------------
-- 5.05  TR_Issue_SubtypeEnforce
--       When a new ISSUE is inserted with Type = 'Bug' /
--       'Feature' / 'Task', a matching row MUST be inserted
--       into the corresponding subtype table within the same
--       transaction. This trigger fires on ISSUE INSERT and
--       validates that the subtype row exists (or will be
--       visible after the outer transaction commits).
--
--       Practical note: the application should insert the
--       supertype row FIRST, then the subtype row in the
--       same transaction. This trigger runs at statement end,
--       so the subtype row will be present if the app follows
--       that order.
-- ----------------------------------------------------------
CREATE OR ALTER TRIGGER TR_Issue_SubtypeEnforce
ON ISSUE
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- Bug rows
    IF EXISTS (
        SELECT 1 FROM INSERTED WHERE Type = 'Bug'
        AND IssueID NOT IN (SELECT IssueID FROM BUG)
    )
    BEGIN
        ROLLBACK TRANSACTION;
        RAISERROR(
            'Each Bug-type ISSUE must have a corresponding row in BUG. '
            'Insert the ISSUE then immediately insert into BUG in the same transaction.', 16, 1);
        RETURN;
    END

    -- Feature rows
    IF EXISTS (
        SELECT 1 FROM INSERTED WHERE Type = 'Feature'
        AND IssueID NOT IN (SELECT IssueID FROM FEATURE)
    )
    BEGIN
        ROLLBACK TRANSACTION;
        RAISERROR(
            'Each Feature-type ISSUE must have a corresponding row in FEATURE. '
            'Insert the ISSUE then immediately insert into FEATURE in the same transaction.', 16, 1);
        RETURN;
    END

    -- Task rows
    IF EXISTS (
        SELECT 1 FROM INSERTED WHERE Type = 'Task'
        AND IssueID NOT IN (SELECT IssueID FROM TASK)
    )
    BEGIN
        ROLLBACK TRANSACTION;
        RAISERROR(
            'Each Task-type ISSUE must have a corresponding row in TASK. '
            'Insert the ISSUE then immediately insert into TASK in the same transaction.', 16, 1);
        RETURN;
    END
END;
GO


-- ============================================================
-- VERIFICATION QUERIES
-- (Run these after seeding data to confirm everything works)
-- ============================================================

-- List all tables created
SELECT TABLE_NAME
FROM   INFORMATION_SCHEMA.TABLES
WHERE  TABLE_TYPE = 'BASE TABLE'
ORDER  BY TABLE_NAME;

-- List all indexes
SELECT  t.name  AS TableName,
        i.name  AS IndexName,
        i.type_desc
FROM    sys.indexes     AS i
JOIN    sys.tables      AS t ON t.object_id = i.object_id
WHERE   i.type > 0                    -- exclude heap
  AND   t.is_ms_shipped = 0
ORDER   BY t.name, i.name;

-- List all views
SELECT TABLE_NAME AS ViewName
FROM   INFORMATION_SCHEMA.VIEWS
ORDER  BY TABLE_NAME;

-- List all triggers
SELECT name AS TriggerName, OBJECT_NAME(parent_id) AS OnTable
FROM   sys.triggers
WHERE  parent_class = 1
ORDER  BY OnTable, name;
GO


-- ============================================================
--  BUG TRACKER  --  Seed Data & Verification
--  Danyal (Data Analyst)
--  NOTE: Schema, indexes, views, and triggers are defined above
--        by Ibrahim. This section only seeds realistic data.
-- ============================================================

-- ============================================================
-- SECTION 6: SEEDING DATA (FIXED FOR TRIGGER COMPLIANCE)
-- ============================================================

-- 1. Disable the subtype enforcement trigger temporarily for seeding
ALTER TABLE ISSUE DISABLE TRIGGER TR_Issue_SubtypeEnforce;
GO

-- 15 USERS
INSERT INTO USERS (UserID, FirstName, LastName, Email, Role) VALUES
(1, 'Aleeza', 'Admin', 'aleeza@company.com', 'Admin'),
(2, 'Ibrahim', 'Manager', 'ibrahim@company.com', 'Manager'),
(3, 'Shaheer', 'Manager', 'shaheer@company.com', 'Manager'),
(4, 'Danyal', 'Dev', 'danyal@company.com', 'Developer'),
(5, 'Eman', 'Dev', 'eman@company.com', 'Developer'),
(6, 'Furkan', 'Dev', 'furkan@company.com', 'Developer'),
(7, 'Gulshan', 'Dev', 'gulshan@company.com', 'Developer'),
(8, 'Haidar', 'Dev', 'haidar@company.com', 'Developer'),
(9, 'Bilal', 'Dev', 'bilal@company.com', 'Developer'),
(10, 'Jameel', 'Dev', 'jameek@company.com', 'Developer'),
(11, 'Mahad', 'QA', 'mahad@company.com', 'QA'),
(12, 'Noor', 'QA', 'noor@company.com', 'QA'),
(13, 'Osman', 'QA', 'osman@company.com', 'QA'),
(14, 'Ahmad', 'Viewer', 'ahmad@company.com', 'Viewer'),
(15, 'Talha', 'Manager', 'talha@company.com', 'Manager');

-- 5 PROJECTS
INSERT INTO PROJECT (ProjectID, Name, Description, StartDate, Status) VALUES
(1, 'Project Alpha', 'Core Platform Overhaul', '2026-01-01', 'Active'),
(2, 'Mobile App', 'Android and iOS development', '2026-02-15', 'Active'),
(3, 'Cloud Migration', 'Legacy data move to AWS', '2026-03-01', 'Active'),
(4, 'External API', 'Public developer portal', '2026-04-10', 'On Hold'),
(5, 'Internal CRM', 'Sales tracking system', '2026-05-01', 'Active');

-- PROJECT MANAGERS
INSERT INTO PROJECT_MEMBER (ProjectID, UserID, MemberRole) VALUES
(1, 2, 'Manager'), (2, 3, 'Manager'), (3, 15, 'Manager'), (4, 2, 'Manager'), (5, 3, 'Manager');

-- 5 SPRINTS
INSERT INTO SPRINT (SprintID, Name, StartDate, EndDate, Status, ProjectID) VALUES
(1, 'Alpha Sprint 1', '2026-05-01', '2026-05-14', 'Active', 1),
(2, 'Mobile UI 1', '2026-05-01', '2026-05-14', 'Active', 2),
(3, 'Migration Phase 1', '2026-04-15', '2026-04-30', 'Completed', 3),
(4, 'CRM Setup', '2026-05-01', '2026-05-20', 'Active', 5),
(5, 'Sprint Holiday', '2026-06-01', '2026-06-14', 'Planning', 1);

-- LABELS
INSERT INTO LABEL (LabelID, Name, Color) VALUES (1, 'Front-End', '#3357FF'), (2, 'Back-End', '#FF5733'), (3, 'Security', '#FF0000');

-- SEEDING 50+ ISSUES
DECLARE @i INT = 1;
WHILE @i <= 55
BEGIN
    DECLARE @pID INT = (@i % 5) + 1;
    DECLARE @uID INT = (@i % 10) + 1;
    DECLARE @Type VARCHAR(10) = CASE WHEN @i % 3 = 0 THEN 'Bug' WHEN @i % 3 = 1 THEN 'Feature' ELSE 'Task' END;
    DECLARE @Priority VARCHAR(10) = CASE WHEN @i % 4 = 0 THEN 'Critical' WHEN @i % 4 = 1 THEN 'High' WHEN @i % 4 = 2 THEN 'Medium' ELSE 'Low' END;
    
    INSERT INTO ISSUE (IssueID, Title, Type, Priority, Status, ProjectID, ReporterID, DueDate)
    VALUES (@i, 'Issue Number ' + CAST(@i AS VARCHAR), @Type, @Priority, 'Open', @pID, @uID, DATEADD(DAY, 7, GETDATE()));

    IF @Type = 'Bug'
        INSERT INTO BUG (IssueID, Severity) VALUES (@i, 'Major');
    ELSE IF @Type = 'Feature'
        INSERT INTO FEATURE (IssueID, BusinessValue) VALUES (@i, 5);
    ELSE
        INSERT INTO TASK (IssueID, TaskType) VALUES (@i, 'Testing');

    INSERT INTO ISSUE_ASSIGNMENT (IssueID, UserID) VALUES (@i, 4 + (@i % 7));
    
    IF @pID IN (1, 2)
        INSERT INTO SPRINT_ISSUE (SprintID, IssueID) VALUES (@pID, @i);

    SET @i = @i + 1;
END;

-- 2. Re-enable the trigger so business rules are back in place
ALTER TABLE ISSUE ENABLE TRIGGER TR_Issue_SubtypeEnforce;
GO

-- SIMULATE ACTIVITY
EXEC sys.sp_set_session_context @key = N'CurrentUserID', @value = 1;
UPDATE ISSUE SET Status = 'In Progress' WHERE IssueID BETWEEN 1 AND 10;
UPDATE ISSUE SET Status = 'In Review' WHERE IssueID BETWEEN 1 AND 5;
UPDATE ISSUE SET Status = 'Done' WHERE IssueID IN (1, 2, 11, 12, 13);
GO

-- ============================================================
-- VERIFICATION QUERIES
-- ============================================================

-- Table and View Checklist
SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE' ORDER BY TABLE_NAME;
SELECT TABLE_NAME AS ViewName FROM INFORMATION_SCHEMA.VIEWS ORDER BY TABLE_NAME;

-- Data Verification
SELECT * FROM VW_OPEN_ISSUES_PER_PROJECT;
SELECT * FROM VW_DEVELOPER_WORKLOAD;
SELECT * FROM VW_SPRINT_VELOCITY;
SELECT * FROM VW_RECENT_ACTIVITY;