# Employee Management App

Full-stack assessment application: **Angular 19 + Spring Boot + MySQL** with JWT authentication, an Employee CRUD screen, and a Report screen with summary statistics and Excel/PDF export.

## Features

| Area | What's implemented |
|---|---|
| Login | Reactive form (username ≥ 3, password ≥ 6, submit disabled until valid), JWT stored in localStorage, error message on invalid credentials, "Remember me" (username), 30-min idle auto-logout with 1-min warning |
| Security | Spring Security filter chain with JWT, BCrypt password hashes, HTTP interceptor attaching the token, AuthGuard on all routes except `/login`, role-based menu and API access |
| Employees (CRUD) | Server-side pagination (10/page), column sorting, 300 ms debounced search with clear, add/edit dialog (row click opens edit), delete confirmation, toast notifications, soft delete |
| Validation | Client: required, email, 10-digit phone, length limits, custom validators (no blank text, no future joining date). Server: Bean Validation + duplicate checks on employee code and email (409) |
| Reports | Date range (defaults to current month, from ≤ to), status and department filters, summary cards (count, total/average salary, by status, by department, by month), read-only paginated/sortable table, Excel (Apache POI) and PDF (OpenPDF) export of all filtered rows |
| Roles | **ADMIN**: everything. **USER**: view, add and edit employees; no delete, no Reports menu or API |

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Angular 19 (standalone components, signals, control flow), Angular Material, RxJS |
| Backend | Spring Boot, Spring Web, Spring Security, Spring Data JPA (Hibernate), Bean Validation, Java 21 |
| Auth | JJWT (HS256) |
| Export | Apache POI (xlsx), OpenPDF (pdf) |
| Database | MySQL 8 |
| Tests | JUnit 5, Mockito |

## Architecture

```
Angular (4200) ──/api proxy──► Spring Boot (8080) ──JPA──► MySQL (3306)
```

```
backend/src/main/java/com/raj/backend
├── config        SecurityConfig, DataSeeder
├── security      JwtUtil, JwtFilter
├── controller    Auth, Employee, Department, Report
├── service       EmployeeService, ReportService, ReportExportService
├── repository    User, Employee, Department, Report (JPQL aggregates)
├── model         AppUser, Employee, Department, EmployeeStatus
├── dto           Request/response records, PageResponse, ReportFilter, ReportSummary
└── exception     NotFound, Duplicate, GlobalExceptionHandler

frontend/src/app
├── core          AuthService, interceptor, guards, IdleService, Employee/Report services, models
├── layout        Shell (toolbar + role-based menu)
├── pages         login, employees (list + dialog), reports
└── shared        ConfirmDialog
```

## Setup

### Prerequisites
- JDK 21+, Node.js 20 or 22, Angular CLI 19 (`npm i -g @angular/cli@19`), Docker (or a local MySQL 8)

### 1. Database
```bash
docker compose up -d
```
This creates database `empdb` (user `root` / password `root`). Tables are created automatically by Hibernate on first run.

### 2. Backend
```bash
cd backend
./mvnw spring-boot:run
```
Runs on http://localhost:8080. On first start it seeds 2 users, 5 departments and 25 employees.

### 3. Frontend
```bash
cd frontend
npm install
ng serve --proxy-config proxy.conf.json
```
Open http://localhost:4200. The proxy forwards `/api` to the backend.

### Default users

| Username | Password | Role |
|---|---|---|
| admin | admin123 | ADMIN |
| user | user123 | USER |

### Configuration (`backend/src/main/resources/application.properties`)
| Property | Default | Notes |
|---|---|---|
| `spring.datasource.*` | localhost:3306/empdb, root/root | |
| `app.jwt.secret` | sample value | **Change in any real deployment** (≥ 32 chars) |
| `app.jwt.expiry-minutes` | 30 | Matches the idle timeout |

## Database Schema

| Table | Key columns | Constraints |
|---|---|---|
| `users` | id, username, password (BCrypt), role | PK, UNIQUE(username), NOT NULL |
| `departments` | id, name | PK, UNIQUE(name), NOT NULL |
| `employees` | id, emp_code, name, email, phone, department_id, designation, salary DECIMAL(12,2), status, joining_date, deleted, created_at, updated_at | PK, UNIQUE(emp_code), UNIQUE(email), FK department_id → departments.id, NOT NULL on all business columns |

Deletes are **soft deletes** (`deleted = true`), so history is preserved and unique values stay reserved.

## API Documentation

All endpoints except `/api/auth/login` require `Authorization: Bearer <token>`. Errors return JSON `{ "message": "...", "errors": { field: message } }`.

### Auth
| Method | Endpoint | Body | Response |
|---|---|---|---|
| POST | `/api/auth/login` | `{ "username", "password" }` | 200 `{ token, username, role }` · 400 validation · 401 invalid credentials |

### Employees
| Method | Endpoint | Notes |
|---|---|---|
| GET | `/api/employees?q=&page=0&size=10&sort=name,asc` | Paged search on name/email/code. Sortable: empCode, name, email, department.name, designation, salary, status, joiningDate |
| GET | `/api/employees/{id}` | 404 if not found |
| POST | `/api/employees` | 201 created · 400 validation · 409 duplicate code/email |
| PUT | `/api/employees/{id}` | 200 · 400 · 404 · 409 |
| DELETE | `/api/employees/{id}` | 204 · **ADMIN only** (403 otherwise) |
| GET | `/api/departments` | List for dropdowns |

Employee request body:
```json
{
  "empCode": "EMP100", "name": "John Doe", "email": "john@company.com", "phone": "9876543210",
  "departmentId": 1, "designation": "Developer", "salary": 50000,
  "status": "ACTIVE", "joiningDate": "2026-11-01"
}
```
`status`: `ACTIVE` | `INACTIVE` | `ON_LEAVE`

### Reports (ADMIN only)
Common optional filters: `from`, `to` (yyyy-MM-dd, on joining date), `status`, `departmentId`. `from > to` returns 400.

| Method | Endpoint | Response |
|---|---|---|
| GET | `/api/reports/employees?...&page=0&size=10&sort=joiningDate,desc` | Paged rows |
| GET | `/api/reports/summary?...` | `{ totalRecords, totalSalary, averageSalary, byStatus, byDepartment, byJoiningMonth }` (SQL COUNT/SUM/AVG/GROUP BY) |
| GET | `/api/reports/export/excel?...` | `.xlsx` download of all filtered rows |
| GET | `/api/reports/export/pdf?...` | `.pdf` download (title, date, period, table, page footer) |

## Security Notes
- Passwords are stored as BCrypt hashes, never in plain text.
- Stateless JWT (HS256) is validated on every request by `JwtFilter`; an expired or invalid token returns 401, and the UI then logs out.
- All queries use JPA/JPQL with bound parameters, so there is no string-concatenated SQL (prevents SQL injection).
- Input is validated on both client and server; the server is the source of truth.
- Role checks are enforced on the **backend** (`SecurityConfig`), not only hidden in the UI.

## Testing
```bash
cd backend && ./mvnw test
```
12 unit tests (JUnit 5 + Mockito, no DB required):
- `EmployeeServiceTest`: create with normalization, duplicate email/code, missing department, update not found, soft delete
- `JwtUtilTest`: generate/parse, tampered token, wrong key, expired token
- `ReportFilterTest`: date range validation

API smoke tests (backend must be running): `scripts/test-crud.sh`, `scripts/test-report.sh`

## Known Limitations / Not Implemented
- Token refresh (optional in UC-LOGIN-03): "Remember me" persists the username only.
- Backend token invalidation on logout (optional in UC-LOGOUT-01): logout clears the client token; the JWT expires after 30 minutes.
- JWT is kept in localStorage as the requirement specifies; an httpOnly cookie would be safer against XSS in production.

## AI Usage
See [AI_USAGE_LOG.md](AI_USAGE_LOG.md).