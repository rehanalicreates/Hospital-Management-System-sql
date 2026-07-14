# 🏥 Hospital Management System — SQL
**Dataset:** Self-generated hospital data | 8 departments · 40 doctors · 3,000 patients · 6,000 appointments · 1,000 admissions
**Tool:** Microsoft SQL Server


---

## 📌 Project Overview

Built a full hospital database from scratch — schema, constraints, and
~19,000 generated records — then used T-SQL to analyze scheduling
patterns, readmission rates, doctor workload, and department revenue.
Includes procedural logic (stored procs, triggers, functions) on top
of the analysis layer.

---

## ✅ Analysis Sections
| Section | Topic |
|---------|-------|
| 1 | Schema — 8 tables, full constraints, FK relationships |
| 2 | Sample Data Generation — tally-table technique, no CSVs |
| 3 | Indexing — proven with `STATISTICS IO` before/after |
| 4 | Functions — patient age (scalar), doctor schedule (table-valued) |
| 5 | Stored Procedures — schedule, admit, discharge, pay, patient history |
| 6 | Triggers — billing audit log, discharge date integrity |
| 7 | Views — doctor workload, department revenue |
| 8 | Business Insights — readmission, no-shows, length of stay, revenue trend |

---

## 💡 Key Findings
| # | Finding |
|---|---------|
| 1 | Adding an index on `Appointments.PatientID` measurably cut logical reads — proven with `STATISTICS IO`, not assumed |
| 2 | ICU and Emergency admissions carry the longest average length of stay |
| 3 | No-show rate varies noticeably by department — a scheduling/reminder opportunity |
| 4 | 30-day readmission rate highlights which departments have the weakest post-discharge follow-up |
| 5 | A small group of patients account for a disproportionate share of overdue billing — clear collections priority list |

---

## 📁 Files
| File | Description |
|------|-------------|
| `hospital_management_system.sql` | Complete SQL script — schema, data generation, procs, triggers, views, 8 analysis queries |
| `README.md` | This file |
## 👤 Author
**Rehan Ali** — Data Analyst
[GitHub](https://github.com/rehanalicreates)
