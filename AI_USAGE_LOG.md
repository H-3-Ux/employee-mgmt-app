# AI Usage Log

**Tool used:** Claude (Anthropic), via chat.
**Approach:** I used AI to plan the build, generate code in small verifiable steps, and debug errors. After every step I compiled, ran the app and tested it (curl scripts, browser) before committing. Nothing was accepted without running it.

---

### 1. Requirement analysis and environment setup
- **Prompt:** "What do I need to do in this assessment?" (shared the use-case document), then "Can I build this online without installing software?"
- **AI output:** Summary of use cases and deliverables; recommended GitHub Codespaces with MySQL in Docker and an Angular dev proxy.
- **Review / changes:** The Codespace came with Java 25 and Node 24. Angular 19 does not officially support Node 24, so I switched to Node 22 via nvm. I generated the backend with Java 21 as the target for stability.
- **Learned:** Codespaces runs everything remotely, so the browser cannot call `localhost:8080` directly; an Angular proxy (`proxy.conf.json`) solves it without CORS configuration.

### 2. JWT authentication (backend)
- **Prompt:** "Implement JWT login for Spring Boot with BCrypt and seeded users."
- **AI output:** User entity, JwtUtil, JwtFilter, SecurityConfig, AuthController, DataSeeder.
- **Review / changes:** Kept the login check simple (`PasswordEncoder.matches`) instead of a full AuthenticationManager setup. Used `jjwt-gson` instead of `jjwt-jackson` to avoid Jackson version conflicts with the newer Spring Boot. Left out Lombok because older Lombok versions fail on newer JDKs. Verified with curl: valid login returns a token, wrong password returns 401.
- **Learned:** How the stateless filter chain works: the JWT filter runs before `UsernamePasswordAuthenticationFilter` and populates the SecurityContext with roles from the token claims.

### 3. Employee CRUD API
- **Prompt:** "Create Employee CRUD with pagination, sorting, search, DTOs, validation and duplicate checks."
- **AI output:** Employee/Department entities (FK), repository with JPQL search, service, controller, DTO records, global exception handler.
- **Review / changes:** Added a separate Department table so the schema has a real foreign key. Chose a soft delete. Restricted DELETE to ADMIN in SecurityConfig. **Build failed:** `PropertyReferenceException` had moved package in the newer Spring Data, so I removed that handler.
- **Learned:** `@EntityGraph` avoids N+1 queries when paging entities with a ManyToOne relation; derived `existsBy...AndIdNot` queries make update-time duplicate checks clean.

### 4. Report API and export
- **Prompt:** "Report endpoints with date/status/department filters, summary with SQL aggregates, Excel and PDF export."
- **AI output:** ReportRepository (COUNT/SUM/AVG/GROUP BY in JPQL), ReportService, export service (Apache POI, OpenPDF), controller.
- **Review / changes:** **Build failed:** wildcard imports from POI and OpenPDF both contain `HeaderFooter`, `Cell` and `Row`, so I replaced the wildcards with explicit imports. Verified the exported files with `file` (xlsx and 2-page PDF) and opened them.
- **Learned:** Optional filters in a single JPQL query (`:param IS NULL OR ...`) avoid writing many query variants; wildcard imports from two libraries can silently create ambiguity.

### 5. Angular: login, guards, interceptor, idle timeout
- **Prompt:** "Angular 19 standalone login with reactive form validation, JWT in localStorage, interceptor, AuthGuard, role-based menu, 30-minute idle logout with warning."
- **AI output:** AuthService (signals), functional interceptor and guards, IdleService, login and shell components.
- **Review / changes:** The idle listeners run outside Angular's zone so mouse movement doesn't trigger change detection constantly. Reports is hidden for USER in the menu **and** blocked by a route guard and the backend, not just hidden. Noticed the Material 3 toolbar ignores `color="primary"` and adjusted the styling.
- **Learned:** Functional interceptors/guards with `inject()`; UI hiding alone is not security, so the backend must enforce roles.

### 6. Employee screen and Reports screen
- **Prompt:** "Material table with server-side paging/sorting, debounced search, add/edit dialog with custom validators, delete confirmation" and "Report screen with date range, filters, summary cards and export download."
- **AI output:** List component, form dialog, confirm dialog, report component and services.
- **Review / changes:** Mapped the `departmentName` sort column to the backend path `department.name`. Server-side 409/400 errors are shown under the matching form field. Dates are formatted in local time (not `toISOString`) to avoid a timezone shift of one day. Fixed text wrapping in table cells and a misleading date-format hint.
- **Learned:** `mat-date-range-input` with a nested form group; downloading a blob with the filename read from `Content-Disposition`.

### 7. Unit tests
- **Prompt:** "Unit tests for critical backend services without needing a database."
- **AI output:** Mockito tests for EmployeeService, JwtUtil and ReportFilter (12 tests).
- **Review / changes:** Removed the default `contextLoads` test because it requires a live MySQL and would fail for anyone running `mvn test` without the DB. All 12 tests pass.
- **Learned:** Mockito strict stubs fail on unused stubbing, which keeps tests precise.

### 8. Process issue
- **Issue:** Pasting long multi-line code into the terminal got garbled (heredoc left waiting for input).
- **Fix:** Pasted long code into script files in the editor and ran them with `bash`, which was reliable.

---

## Summary
AI significantly sped up boilerplate (entities, DTOs, Material templates). The real effort was verification: compiling, running each layer, testing with scripts and the browser, and fixing version-specific problems the AI could not anticipate (Java/Node versions, changed packages, import clashes). I reviewed the security-relevant parts most closely: password hashing, JWT validation, backend role checks, and parameterized queries.