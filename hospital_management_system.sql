/* ============================================================================
   HOSPITAL MANAGEMENT SYSTEM — SQL Server / T-SQL Portfolio Project
   Author: Ali (rehanalicreates)
   Purpose: Recruiter-facing project demonstrating schema design, procedural
            T-SQL (procs, triggers, functions), indexing decisions backed by
            evidence, and business-driven analytical queries.

   HOW TO RUN:
   1. Open in SSMS, execute top to bottom (F5). Takes ~30-60 seconds due to
      data generation loops.
   2. Everything is self-contained — no external files, no sample CSVs.
   ============================================================================ */

SET NOCOUNT ON;
GO

IF DB_ID('HospitalDB') IS NOT NULL
BEGIN
    ALTER DATABASE HospitalDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE HospitalDB;
END
GO

CREATE DATABASE HospitalDB;
GO

USE HospitalDB;
GO

/* ============================================================================
   1. SCHEMA
   ============================================================================ */

CREATE TABLE Departments (
    DepartmentID    INT IDENTITY(1,1) PRIMARY KEY,
    DepartmentName  VARCHAR(50) NOT NULL,
    Location        VARCHAR(50) NOT NULL,
    Budget          DECIMAL(12,2) NOT NULL CHECK (Budget >= 0)
);

CREATE TABLE Doctors (
    DoctorID        INT IDENTITY(1,1) PRIMARY KEY,
    FirstName       VARCHAR(30) NOT NULL,
    LastName        VARCHAR(30) NOT NULL,
    Specialization  VARCHAR(50) NOT NULL,
    DepartmentID    INT NOT NULL FOREIGN KEY REFERENCES Departments(DepartmentID),
    HireDate        DATE NOT NULL,
    Salary          DECIMAL(10,2) NOT NULL CHECK (Salary > 0)
);

CREATE TABLE Patients (
    PatientID           INT IDENTITY(1,1) PRIMARY KEY,
    FirstName           VARCHAR(30) NOT NULL,
    LastName            VARCHAR(30) NOT NULL,
    DOB                 DATE NOT NULL,
    Gender              CHAR(1) NOT NULL CHECK (Gender IN ('M','F')),
    BloodGroup          VARCHAR(3) NOT NULL,
    Phone               VARCHAR(15) NOT NULL,
    RegistrationDate    DATE NOT NULL
);

CREATE TABLE Appointments (
    AppointmentID       INT IDENTITY(1,1) PRIMARY KEY,
    PatientID           INT NOT NULL FOREIGN KEY REFERENCES Patients(PatientID),
    DoctorID            INT NOT NULL FOREIGN KEY REFERENCES Doctors(DoctorID),
    AppointmentDate     DATE NOT NULL,
    AppointmentTime     TIME NOT NULL,
    Status              VARCHAR(15) NOT NULL CHECK (Status IN ('Scheduled','Completed','Cancelled','NoShow')),
    Reason              VARCHAR(100) NOT NULL
);

CREATE TABLE Admissions (
    AdmissionID     INT IDENTITY(1,1) PRIMARY KEY,
    PatientID       INT NOT NULL FOREIGN KEY REFERENCES Patients(PatientID),
    DoctorID        INT NOT NULL FOREIGN KEY REFERENCES Doctors(DoctorID),
    AdmissionDate   DATE NOT NULL,
    DischargeDate   DATE NULL,
    RoomNumber      INT NOT NULL,
    AdmissionType   VARCHAR(20) NOT NULL CHECK (AdmissionType IN ('Emergency','Elective','Maternity','ICU')),
    DiagnosisCode   VARCHAR(10) NOT NULL,
    CHECK (DischargeDate IS NULL OR DischargeDate >= AdmissionDate)
);

CREATE TABLE Billing (
    BillID          INT IDENTITY(1,1) PRIMARY KEY,
    PatientID       INT NOT NULL FOREIGN KEY REFERENCES Patients(PatientID),
    AdmissionID     INT NULL FOREIGN KEY REFERENCES Admissions(AdmissionID),
    AppointmentID   INT NULL FOREIGN KEY REFERENCES Appointments(AppointmentID),
    BillDate        DATE NOT NULL,
    Amount          DECIMAL(10,2) NOT NULL CHECK (Amount >= 0),
    PaymentStatus   VARCHAR(10) NOT NULL CHECK (PaymentStatus IN ('Paid','Pending','Overdue')),
    PaymentMethod   VARCHAR(15) NOT NULL
);

CREATE TABLE MedicalRecords (
    RecordID        INT IDENTITY(1,1) PRIMARY KEY,
    PatientID       INT NOT NULL FOREIGN KEY REFERENCES Patients(PatientID),
    DoctorID        INT NOT NULL FOREIGN KEY REFERENCES Doctors(DoctorID),
    VisitDate       DATE NOT NULL,
    Diagnosis       VARCHAR(100) NOT NULL,
    Treatment       VARCHAR(150) NOT NULL
);

CREATE TABLE BillingAudit (
    AuditID         INT IDENTITY(1,1) PRIMARY KEY,
    BillID          INT NOT NULL,
    OldAmount       DECIMAL(10,2) NOT NULL,
    NewAmount       DECIMAL(10,2) NOT NULL,
    OldStatus       VARCHAR(10) NOT NULL,
    NewStatus       VARCHAR(10) NOT NULL,
    ChangedBy       VARCHAR(50) NOT NULL DEFAULT SUSER_SNAME(),
    ChangedDate     DATETIME NOT NULL DEFAULT GETDATE()
);
GO

ALTER TABLE Billing ADD CONSTRAINT CK_Billing_PaymentMethod
CHECK (PaymentMethod IN ('Cash','Card','Insurance','Online','Cheque'));
GO

CREATE UNIQUE NONCLUSTERED INDEX UQ_Appointments_DoctorSlot
ON Appointments(DoctorID, AppointmentDate, AppointmentTime)
WHERE Status IN ('Scheduled','NoShow');
GO

/* ============================================================================
   2. SAMPLE DATA GENERATION
   Uses a tally table (no external CSVs) so the whole project is one runnable
   file. Volumes are big enough to make indexing decisions actually matter.
   ============================================================================ */

-- Tally table: 10,000 sequential numbers
IF OBJECT_ID('tempdb..#Tally') IS NOT NULL DROP TABLE #Tally;
SELECT TOP (10000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS N
INTO #Tally
FROM sys.all_objects a CROSS JOIN sys.all_objects b;

-- Name pools for realistic-looking generated data
IF OBJECT_ID('tempdb..#FirstNames') IS NOT NULL DROP TABLE #FirstNames;
CREATE TABLE #FirstNames (ID INT IDENTITY(1,1), Name VARCHAR(30));
INSERT INTO #FirstNames (Name) VALUES
('Ahmed'),('Sara'),('Bilal'),('Ayesha'),('Hassan'),('Fatima'),('Usman'),('Zara'),
('Omar'),('Hira'),('Ali'),('Mahnoor'),('Kamran'),('Sana'),('Faisal'),('Nida'),
('Imran'),('Amna'),('Tariq'),('Rabia'),('Adeel'),('Sadia'),('Danish'),('Iqra'),
('Rizwan'),('Mehwish'),('Salman'),('Komal'),('Junaid'),('Areeba');

IF OBJECT_ID('tempdb..#LastNames') IS NOT NULL DROP TABLE #LastNames;
CREATE TABLE #LastNames (ID INT IDENTITY(1,1), Name VARCHAR(30));
INSERT INTO #LastNames (Name) VALUES
('Khan'),('Ahmed'),('Malik'),('Raza'),('Sheikh'),('Butt'),('Qureshi'),('Farooq'),
('Iqbal'),('Chaudhry'),('Abbasi'),('Hashmi'),('Rana'),('Baig'),('Soomro'),('Awan');

-- 2.1 Departments (fixed — a real hospital has a known set)
INSERT INTO Departments (DepartmentName, Location, Budget) VALUES
('Cardiology','Block A',5000000),
('Neurology','Block A',4200000),
('Orthopedics','Block B',3800000),
('Pediatrics','Block C',3000000),
('Oncology','Block B',6000000),
('Emergency','Block D',7000000),
('Gynecology','Block C',3200000),
('General Surgery','Block B',4500000);

-- 2.2 Doctors (40)
INSERT INTO Doctors (FirstName, LastName, Specialization, DepartmentID, HireDate, Salary)
SELECT
    fn.Name,
    ln.Name,
    d.DepartmentName,
    d.DepartmentID,
    DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 3650, GETDATE()),
    120000 + (ABS(CHECKSUM(NEWID())) % 15) * 10000
FROM #Tally t
JOIN #FirstNames fn ON fn.ID = ((t.N - 1) % 30) + 1
JOIN #LastNames ln ON ln.ID = ((t.N * 7 - 1) % 16) + 1
JOIN Departments d ON d.DepartmentID = ((t.N - 1) % 8) + 1
WHERE t.N <= 40;

-- 2.3 Patients (3000)
INSERT INTO Patients (FirstName, LastName, DOB, Gender, BloodGroup, Phone, RegistrationDate)
SELECT
    fn.Name,
    ln.Name,
    DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 25550, GETDATE()),   -- up to ~70 yrs old
    CASE WHEN t.N % 2 = 0 THEN 'M' ELSE 'F' END,
    CASE (t.N % 8)
        WHEN 0 THEN 'A+' WHEN 1 THEN 'A-' WHEN 2 THEN 'B+' WHEN 3 THEN 'B-'
        WHEN 4 THEN 'O+' WHEN 5 THEN 'O-' WHEN 6 THEN 'AB+' ELSE 'AB-' END,
    '0300' + RIGHT('0000000' + CAST(t.N AS VARCHAR(10)), 7),
    DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 1460, GETDATE())      -- registered within last 4 yrs
FROM #Tally t
JOIN #FirstNames fn ON fn.ID = ((t.N * 3 - 1) % 30) + 1
JOIN #LastNames ln ON ln.ID = ((t.N * 11 - 1) % 16) + 1
WHERE t.N <= 3000;

-- 2.4 Appointments (6000) — weighted status distribution
-- CROSS APPLY draws ONE random pct per row; using NEWID() again inside each
-- CASE branch would re-roll for every WHEN check and quietly wreck the
-- weighting (a classic "looks random, isn't" bug).
INSERT INTO Appointments (PatientID, DoctorID, AppointmentDate, AppointmentTime, Status, Reason)
SELECT
    ((ABS(CHECKSUM(NEWID())) % 3000) + 1),
    ((ABS(CHECKSUM(NEWID())) % 40) + 1),
    DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 730, CAST(GETDATE() AS DATE)),
    CAST(DATEADD(MINUTE, (ABS(CHECKSUM(NEWID())) % 480), '09:00') AS TIME),
    CASE
        WHEN r.pct < 65 THEN 'Completed'
        WHEN r.pct < 80 THEN 'Scheduled'
        WHEN r.pct < 92 THEN 'Cancelled'
        ELSE 'NoShow'
    END,
    CASE (t.N % 6)
        WHEN 0 THEN 'Routine Checkup' WHEN 1 THEN 'Follow-up'
        WHEN 2 THEN 'Consultation' WHEN 3 THEN 'Lab Review'
        WHEN 4 THEN 'Vaccination' ELSE 'Chronic Care Review' END
FROM #Tally t
CROSS APPLY (SELECT ABS(CHECKSUM(NEWID())) % 100 AS pct) r
WHERE t.N <= 6000;

-- 2.5 Admissions (1000) — subset needs discharge dates for length-of-stay analysis
INSERT INTO Admissions (PatientID, DoctorID, AdmissionDate, DischargeDate, RoomNumber, AdmissionType, DiagnosisCode)
SELECT
    ((ABS(CHECKSUM(NEWID())) % 3000) + 1),
    ((ABS(CHECKSUM(NEWID())) % 40) + 1),
    admit_date,
    CASE WHEN t.N % 20 = 0 THEN NULL  -- ~5% still admitted (currently in hospital)
         ELSE DATEADD(DAY, 1 + ABS(CHECKSUM(NEWID())) % 12, admit_date) END,
    100 + (ABS(CHECKSUM(NEWID())) % 150),
    CASE (t.N % 4)
        WHEN 0 THEN 'Emergency' WHEN 1 THEN 'Elective'
        WHEN 2 THEN 'Maternity' ELSE 'ICU' END,
    'D' + RIGHT('000' + CAST((ABS(CHECKSUM(NEWID())) % 50) + 1 AS VARCHAR(3)), 3)
FROM (
    SELECT N, DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 730, CAST(GETDATE() AS DATE)) AS admit_date
    FROM #Tally WHERE N <= 1000
) t;

-- 2.6 Billing — generated from admissions and completed appointments
INSERT INTO Billing (PatientID, AdmissionID, AppointmentID, BillDate, Amount, PaymentStatus, PaymentMethod)
SELECT
    a.PatientID,
    a.AdmissionID,
    NULL,
    ISNULL(a.DischargeDate, CAST(GETDATE() AS DATE)),
    5000 + (ABS(CHECKSUM(NEWID())) % 95000),
    CASE WHEN r.pct < 70 THEN 'Paid'
         WHEN r.pct < 90 THEN 'Pending'
         ELSE 'Overdue' END,
    CASE (a.AdmissionID % 3) WHEN 0 THEN 'Cash' WHEN 1 THEN 'Card' ELSE 'Insurance' END
FROM Admissions a
CROSS APPLY (SELECT ABS(CHECKSUM(NEWID())) % 100 AS pct) r;

INSERT INTO Billing (PatientID, AdmissionID, AppointmentID, BillDate, Amount, PaymentStatus, PaymentMethod)
SELECT
    ap.PatientID,
    NULL,
    ap.AppointmentID,
    ap.AppointmentDate,
    1500 + (ABS(CHECKSUM(NEWID())) % 8500),
    CASE WHEN r.pct < 80 THEN 'Paid'
         WHEN r.pct < 93 THEN 'Pending'
         ELSE 'Overdue' END,
    CASE (ap.AppointmentID % 3) WHEN 0 THEN 'Cash' WHEN 1 THEN 'Card' ELSE 'Insurance' END
FROM Appointments ap
CROSS APPLY (SELECT ABS(CHECKSUM(NEWID())) % 100 AS pct) r
WHERE ap.Status = 'Completed';

-- 2.7 Medical Records — tied to admissions
INSERT INTO MedicalRecords (PatientID, DoctorID, VisitDate, Diagnosis, Treatment)
SELECT
    a.PatientID,
    a.DoctorID,
    a.AdmissionDate,
    CASE (a.AdmissionID % 10)
        WHEN 0 THEN 'Hypertension' WHEN 1 THEN 'Type 2 Diabetes'
        WHEN 2 THEN 'Fracture' WHEN 3 THEN 'Pneumonia'
        WHEN 4 THEN 'Appendicitis' WHEN 5 THEN 'Migraine'
        WHEN 6 THEN 'Cardiac Arrhythmia' WHEN 7 THEN 'Asthma'
        WHEN 8 THEN 'Kidney Stones' ELSE 'Post-Surgical Recovery' END,
    CASE (a.AdmissionID % 5)
        WHEN 0 THEN 'Medication + monitoring' WHEN 1 THEN 'Surgery + physiotherapy'
        WHEN 2 THEN 'IV therapy + observation' WHEN 3 THEN 'Surgical intervention'
        ELSE 'Outpatient follow-up plan' END
FROM Admissions a;

DROP TABLE #Tally, #FirstNames, #LastNames;
GO

PRINT 'Row counts:';
SELECT 'Departments' AS TableName, COUNT(*) AS Rows FROM Departments
UNION ALL SELECT 'Doctors', COUNT(*) FROM Doctors
UNION ALL SELECT 'Patients', COUNT(*) FROM Patients
UNION ALL SELECT 'Appointments', COUNT(*) FROM Appointments
UNION ALL SELECT 'Admissions', COUNT(*) FROM Admissions
UNION ALL SELECT 'Billing', COUNT(*) FROM Billing
UNION ALL SELECT 'MedicalRecords', COUNT(*) FROM MedicalRecords;
GO

/* ============================================================================
   3. INDEXING — EVIDENCE-BASED, NOT ASSUMED
   We prove the index helps using STATISTICS IO before/after instead of just
   assuming it does.
   ============================================================================ */

SET STATISTICS IO ON;
GO
-- BEFORE: no index on Appointments.PatientID — full scan to find one patient's history
SELECT AppointmentID, AppointmentDate, Status
FROM Appointments
WHERE PatientID = 1500;
GO
SET STATISTICS IO OFF;
GO

CREATE NONCLUSTERED INDEX IX_Appointments_PatientID ON Appointments(PatientID) INCLUDE (AppointmentDate, Status);
CREATE NONCLUSTERED INDEX IX_Appointments_DoctorID_Date ON Appointments(DoctorID, AppointmentDate, AppointmentTime);
CREATE NONCLUSTERED INDEX IX_Admissions_PatientID ON Admissions(PatientID) INCLUDE (AdmissionDate, DischargeDate);
CREATE NONCLUSTERED INDEX IX_Billing_PaymentStatus ON Billing(PaymentStatus) INCLUDE (Amount, BillDate);
CREATE NONCLUSTERED INDEX IX_Billing_PatientID ON Billing(PatientID);
GO

SET STATISTICS IO ON;
GO
-- AFTER: same query, now uses IX_Appointments_PatientID — compare logical reads to the run above
SELECT AppointmentID, AppointmentDate, Status
FROM Appointments
WHERE PatientID = 1500;
GO
SET STATISTICS IO OFF;
GO

/* ============================================================================
   4. FUNCTIONS
   ============================================================================ */

-- Scalar function: patient's current age
CREATE FUNCTION dbo.fn_PatientAge (@DOB DATE)
RETURNS INT
AS
BEGIN
    RETURN DATEDIFF(YEAR, @DOB, GETDATE())
           - CASE WHEN (MONTH(@DOB) > MONTH(GETDATE()))
                    OR (MONTH(@DOB) = MONTH(GETDATE()) AND DAY(@DOB) > DAY(GETDATE()))
                  THEN 1 ELSE 0 END;
END
GO

-- Table-valued function: a doctor's appointments in a date range
CREATE FUNCTION dbo.fn_DoctorSchedule (@DoctorID INT, @StartDate DATE, @EndDate DATE)
RETURNS TABLE
AS
RETURN (
    SELECT a.AppointmentID, a.AppointmentDate, a.AppointmentTime, a.Status,
           p.FirstName + ' ' + p.LastName AS PatientName
    FROM Appointments a
    JOIN Patients p ON p.PatientID = a.PatientID
    WHERE a.DoctorID = @DoctorID
      AND a.AppointmentDate BETWEEN @StartDate AND @EndDate
);
GO

/* ============================================================================
   5. STORED PROCEDURES
   Every write procedure uses TRY/CATCH + explicit transactions — no partial
   writes if something fails midway.
   ============================================================================ */

-- 5.1 Schedule an appointment, blocking double-booking for the same doctor/slot
CREATE PROCEDURE dbo.usp_ScheduleAppointment
    @PatientID INT,
    @DoctorID INT,
    @AppointmentDate DATE,
    @AppointmentTime TIME,
    @Reason VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
        IF EXISTS (
            SELECT 1 FROM Appointments
            WHERE DoctorID = @DoctorID
              AND AppointmentDate = @AppointmentDate
              AND AppointmentTime = @AppointmentTime
              AND Status IN ('Scheduled','Completed','NoShow')
        )
        BEGIN
            RAISERROR('This doctor already has an appointment at that date/time.', 16, 1);
            RETURN;
        END

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO Appointments (PatientID, DoctorID, AppointmentDate, AppointmentTime, Status, Reason)
        VALUES (@PatientID, @DoctorID, @AppointmentDate, @AppointmentTime, 'Scheduled', @Reason);

        COMMIT TRANSACTION;
        SELECT SCOPE_IDENTITY() AS NewAppointmentID;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- 5.2 Admit a patient, blocking a room that's already occupied
CREATE PROCEDURE dbo.usp_AdmitPatient
    @PatientID INT,
    @DoctorID INT,
    @RoomNumber INT,
    @AdmissionType VARCHAR(20),
    @DiagnosisCode VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
        IF EXISTS (
            SELECT 1 FROM Admissions
            WHERE RoomNumber = @RoomNumber AND DischargeDate IS NULL
        )
        BEGIN
            RAISERROR('Room %d is currently occupied.', 16, 1, @RoomNumber);
            RETURN;
        END

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO Admissions (PatientID, DoctorID, AdmissionDate, DischargeDate, RoomNumber, AdmissionType, DiagnosisCode)
        VALUES (@PatientID, @DoctorID, CAST(GETDATE() AS DATE), NULL, @RoomNumber, @AdmissionType, @DiagnosisCode);

        COMMIT TRANSACTION;
        SELECT SCOPE_IDENTITY() AS NewAdmissionID;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- 5.3 Discharge a patient and auto-generate their bill in the same transaction
CREATE PROCEDURE dbo.usp_DischargePatient
    @AdmissionID INT,
    @BillAmount DECIMAL(10,2),
    @PaymentMethod VARCHAR(15)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM Admissions WHERE AdmissionID = @AdmissionID AND DischargeDate IS NULL)
        BEGIN
            RAISERROR('Admission not found or patient already discharged.', 16, 1);
            RETURN;
        END

        UPDATE Admissions
        SET DischargeDate = CAST(GETDATE() AS DATE)
        WHERE AdmissionID = @AdmissionID;

        INSERT INTO Billing (PatientID, AdmissionID, AppointmentID, BillDate, Amount, PaymentStatus, PaymentMethod)
        SELECT PatientID, AdmissionID, NULL, CAST(GETDATE() AS DATE), @BillAmount, 'Pending', @PaymentMethod
        FROM Admissions WHERE AdmissionID = @AdmissionID;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- 5.4 Process a payment against a bill
CREATE PROCEDURE dbo.usp_ProcessPayment
    @BillID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM Billing WHERE BillID = @BillID)
        BEGIN
            RAISERROR('Bill %d does not exist.', 16, 1, @BillID);
            RETURN;
        END

        IF EXISTS (SELECT 1 FROM Billing WHERE BillID = @BillID AND PaymentStatus = 'Paid')
        BEGIN
            RAISERROR('Bill %d is already paid.', 16, 1, @BillID);
            RETURN;
        END

        UPDATE Billing
        SET PaymentStatus = 'Paid'
        WHERE BillID = @BillID;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- 5.5 Full patient history — appointments, admissions, bills, records in one call
CREATE PROCEDURE dbo.usp_GetPatientHistory
    @PatientID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 'Appointment' AS RecordType, AppointmentDate AS EventDate, Status AS Detail
    FROM Appointments WHERE PatientID = @PatientID
    UNION ALL
    SELECT 'Admission', AdmissionDate, AdmissionType FROM Admissions WHERE PatientID = @PatientID
    UNION ALL
    SELECT 'Bill', BillDate, PaymentStatus + ' - Rs.' + CAST(Amount AS VARCHAR(20)) FROM Billing WHERE PatientID = @PatientID
    ORDER BY EventDate DESC;
END
GO

/* ============================================================================
   6. TRIGGERS
   ============================================================================ */

-- Every change to a bill's amount or status gets logged automatically
CREATE TRIGGER trg_BillingAudit ON Billing
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF UPDATE(Amount) OR UPDATE(PaymentStatus)
    BEGIN
        INSERT INTO BillingAudit (BillID, OldAmount, NewAmount, OldStatus, NewStatus)
        SELECT i.BillID, d.Amount, i.Amount, d.PaymentStatus, i.PaymentStatus
        FROM inserted i
        JOIN deleted d ON d.BillID = i.BillID;
    END
END
GO

-- Block inserting a discharge date earlier than the admission date
-- (defense in depth — the CHECK constraint covers INSERT, this covers UPDATE)
CREATE TRIGGER trg_ValidDischargeDate ON Admissions
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted WHERE DischargeDate < AdmissionDate)
    BEGIN
        RAISERROR('Discharge date cannot be earlier than admission date.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END
GO

/* ============================================================================
   7. VIEWS
   ============================================================================ */

CREATE VIEW vw_DoctorWorkload AS
SELECT
    doc.DoctorID,
    doc.FirstName + ' ' + doc.LastName AS DoctorName,
    dep.DepartmentName,
    COUNT(a.AppointmentID) AS TotalAppointments,
    SUM(CASE WHEN a.Status = 'Completed' THEN 1 ELSE 0 END) AS Completed,
    SUM(CASE WHEN a.Status = 'NoShow' THEN 1 ELSE 0 END) AS NoShows
FROM Doctors doc
JOIN Departments dep ON dep.DepartmentID = doc.DepartmentID
LEFT JOIN Appointments a ON a.DoctorID = doc.DoctorID
GROUP BY doc.DoctorID, doc.FirstName, doc.LastName, dep.DepartmentName;
GO

CREATE VIEW vw_DepartmentRevenue AS
SELECT
    dep.DepartmentName,
    SUM(b.Amount) AS TotalBilled,
    SUM(CASE WHEN b.PaymentStatus = 'Paid' THEN b.Amount ELSE 0 END) AS Collected,
    SUM(CASE WHEN b.PaymentStatus = 'Overdue' THEN b.Amount ELSE 0 END) AS Overdue
FROM Billing b
LEFT JOIN Admissions ad ON ad.AdmissionID = b.AdmissionID
LEFT JOIN Appointments ap ON ap.AppointmentID = b.AppointmentID
JOIN Doctors doc ON doc.DoctorID = COALESCE(ad.DoctorID, ap.DoctorID)
JOIN Departments dep ON dep.DepartmentID = doc.DepartmentID
GROUP BY dep.DepartmentName;
GO

/* ============================================================================
   8. ANALYTICAL QUERIES — the business questions a hospital admin actually asks
   ============================================================================ */

-- 8.1 30-day readmission rate per department
;WITH DischargedAdmissions AS (
    SELECT AdmissionID, PatientID, DoctorID, AdmissionDate, DischargeDate
    FROM Admissions
    WHERE DischargeDate IS NOT NULL
)
SELECT
    dep.DepartmentName,
    COUNT(DISTINCT d1.AdmissionID) AS TotalDischarges,
    COUNT(DISTINCT d2.AdmissionID) AS Readmissions30Day,
    CAST(100.0 * COUNT(DISTINCT d2.AdmissionID) / NULLIF(COUNT(DISTINCT d1.AdmissionID), 0) AS DECIMAL(5,2)) AS ReadmitRatePct
FROM DischargedAdmissions d1
JOIN Doctors doc ON doc.DoctorID = d1.DoctorID
JOIN Departments dep ON dep.DepartmentID = doc.DepartmentID
LEFT JOIN DischargedAdmissions d2
    ON d2.PatientID = d1.PatientID
    AND d2.AdmissionDate > d1.DischargeDate
    AND d2.AdmissionDate <= DATEADD(DAY, 30, d1.DischargeDate)
GROUP BY dep.DepartmentName
ORDER BY ReadmitRatePct DESC;

-- 8.2 No-show rate by department (patients booking and not showing up costs money)
SELECT
    dep.DepartmentName,
    COUNT(*) AS TotalAppointments,
    SUM(CASE WHEN a.Status = 'NoShow' THEN 1 ELSE 0 END) AS NoShows,
    CAST(100.0 * SUM(CASE WHEN a.Status = 'NoShow' THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS NoShowRatePct
FROM Appointments a
JOIN Doctors doc ON doc.DoctorID = a.DoctorID
JOIN Departments dep ON dep.DepartmentID = doc.DepartmentID
GROUP BY dep.DepartmentName
ORDER BY NoShowRatePct DESC;

-- 8.3 Average length of stay by admission type
SELECT
    AdmissionType,
    COUNT(*) AS TotalAdmissions,
    AVG(DATEDIFF(DAY, AdmissionDate, DischargeDate) * 1.0) AS AvgLengthOfStayDays
FROM Admissions
WHERE DischargeDate IS NOT NULL
GROUP BY AdmissionType
ORDER BY AvgLengthOfStayDays DESC;

-- 8.4 Monthly revenue trend, all departments
SELECT
    FORMAT(BillDate, 'yyyy-MM') AS BillMonth,
    SUM(Amount) AS TotalBilled,
    SUM(CASE WHEN PaymentStatus = 'Paid' THEN Amount ELSE 0 END) AS Collected
FROM Billing
GROUP BY FORMAT(BillDate, 'yyyy-MM')
ORDER BY BillMonth;

-- 8.5 Top 5 doctors by completed appointment volume
SELECT TOP 5
    doc.FirstName + ' ' + doc.LastName AS DoctorName,
    dep.DepartmentName,
    COUNT(*) AS CompletedAppointments
FROM Appointments a
JOIN Doctors doc ON doc.DoctorID = a.DoctorID
JOIN Departments dep ON dep.DepartmentID = doc.DepartmentID
WHERE a.Status = 'Completed'
GROUP BY doc.FirstName, doc.LastName, dep.DepartmentName
ORDER BY CompletedAppointments DESC;

-- 8.6 Patients with overdue bills over Rs. 20,000 (collections priority list)
SELECT
    p.PatientID,
    p.FirstName + ' ' + p.LastName AS PatientName,
    p.Phone,
    SUM(b.Amount) AS TotalOverdue
FROM Billing b
JOIN Patients p ON p.PatientID = b.PatientID
WHERE b.PaymentStatus = 'Overdue'
GROUP BY p.PatientID, p.FirstName, p.LastName, p.Phone
HAVING SUM(b.Amount) > 20000
ORDER BY TotalOverdue DESC;

-- 8.7 Most common diagnoses (resource planning)
SELECT TOP 10
    Diagnosis,
    COUNT(*) AS CaseCount
FROM MedicalRecords
GROUP BY Diagnosis
ORDER BY CaseCount DESC;

/* ============================================================================
   END OF SCRIPT
   ============================================================================ */
