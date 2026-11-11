#!/bin/bash
set -e
cd /workspaces/employee-mgmt-app/frontend
grep -q '"@angular/material"' package.json || { echo "ERROR: Angular Material missing. Run: ng add @angular/material@19 --skip-confirmation --defaults"; exit 1; }
A=src/app
mkdir -p $A/core $A/layout $A/pages/login $A/pages/employees $A/pages/reports $A/shared
rm -f $A/app.component.html $A/app.component.scss $A/app.component.spec.ts

# ---------- models ----------
cat > $A/core/models.ts << 'EOF'
export interface LoginResponse { token: string; username: string; role: 'ADMIN' | 'USER'; }
export interface Department { id: number; name: string; }
export type EmployeeStatus = 'ACTIVE' | 'INACTIVE' | 'ON_LEAVE';
export interface Employee {
  id: number; empCode: string; name: string; email: string; phone: string;
  departmentId: number; departmentName: string; designation: string;
  salary: number; status: EmployeeStatus; joiningDate: string;
}
export type EmployeeRequest = Omit<Employee, 'id' | 'departmentName'>;
export interface Page<T> { content: T[]; page: number; size: number; totalElements: number; totalPages: number; }
export interface ReportSummary {
  totalRecords: number; totalSalary: number; averageSalary: number;
  byStatus: Record<string, number>; byDepartment: Record<string, number>; byJoiningMonth: Record<string, number>;
}
export const STATUSES: EmployeeStatus[] = ['ACTIVE', 'INACTIVE', 'ON_LEAVE'];

/** Formats a Date as yyyy-MM-dd in local time (avoids UTC shift of toISOString). */
export function toIsoDate(d: Date | null | undefined): string | null {
  if (!d) return null;
  const p = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}
EOF

# ---------- auth service ----------
cat > $A/core/auth.service.ts << 'EOF'
import { Injectable, computed, inject, signal } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Router } from '@angular/router';
import { Observable, tap } from 'rxjs';
import { LoginResponse } from './models';

const TOKEN_KEY = 'emp_token';
const USER_KEY = 'emp_user';
const REMEMBER_KEY = 'emp_remember_username';

interface SessionUser { username: string; role: 'ADMIN' | 'USER'; }

@Injectable({ providedIn: 'root' })
export class AuthService {
  private http = inject(HttpClient);
  private router = inject(Router);

  readonly user = signal<SessionUser | null>(this.readUser());
  readonly isAdmin = computed(() => this.user()?.role === 'ADMIN');

  login(username: string, password: string, remember: boolean): Observable<LoginResponse> {
    return this.http.post<LoginResponse>('/api/auth/login', { username, password }).pipe(
      tap(res => {
        localStorage.setItem(TOKEN_KEY, res.token);
        localStorage.setItem(USER_KEY, JSON.stringify({ username: res.username, role: res.role }));
        if (remember) localStorage.setItem(REMEMBER_KEY, username);
        else localStorage.removeItem(REMEMBER_KEY);
        this.user.set({ username: res.username, role: res.role });
      })
    );
  }

  logout(reason?: 'idle' | 'expired'): void {
    this.clearSession();
    this.router.navigate(['/login'], reason ? { queryParams: { reason } } : {});
  }

  clearSession(): void {
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(USER_KEY);
    this.user.set(null);
  }

  get token(): string | null { return localStorage.getItem(TOKEN_KEY); }

  isLoggedIn(): boolean {
    const t = this.token;
    if (!t) return false;
    try {
      const payload = JSON.parse(atob(t.split('.')[1].replace(/-/g, '+').replace(/_/g, '/')));
      return payload.exp * 1000 > Date.now();
    } catch {
      return false;
    }
  }

  rememberedUsername(): string { return localStorage.getItem(REMEMBER_KEY) ?? ''; }

  private readUser(): SessionUser | null {
    const s = localStorage.getItem(USER_KEY);
    return s ? JSON.parse(s) : null;
  }
}
EOF

# ---------- interceptor ----------
cat > $A/core/auth.interceptor.ts << 'EOF'
import { HttpErrorResponse, HttpInterceptorFn } from '@angular/common/http';
import { inject } from '@angular/core';
import { catchError, throwError } from 'rxjs';
import { AuthService } from './auth.service';

export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const auth = inject(AuthService);
  const isAuthCall = req.url.includes('/api/auth/');
  const token = auth.token;
  const request = token && !isAuthCall
    ? req.clone({ setHeaders: { Authorization: `Bearer ${token}` } })
    : req;

  return next(request).pipe(
    catchError((err: HttpErrorResponse) => {
      if (err.status === 401 && !isAuthCall) auth.logout('expired');
      return throwError(() => err);
    })
  );
};
EOF

# ---------- guards ----------
cat > $A/core/auth.guards.ts << 'EOF'
import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { AuthService } from './auth.service';

export const authGuard: CanActivateFn = () => {
  const auth = inject(AuthService);
  if (auth.isLoggedIn()) return true;
  auth.clearSession();
  return inject(Router).createUrlTree(['/login']);
};

export const adminGuard: CanActivateFn = () =>
  inject(AuthService).isAdmin() ? true : inject(Router).createUrlTree(['/employees']);

export const loginGuard: CanActivateFn = () =>
  inject(AuthService).isLoggedIn() ? inject(Router).createUrlTree(['/employees']) : true;
EOF

# ---------- idle timeout ----------
cat > $A/core/idle.service.ts << 'EOF'
import { Injectable, NgZone, inject } from '@angular/core';
import { MatSnackBar } from '@angular/material/snack-bar';
import { AuthService } from './auth.service';

const EVENTS = ['mousemove', 'keydown', 'click', 'scroll', 'touchstart'];

@Injectable({ providedIn: 'root' })
export class IdleService {
  private auth = inject(AuthService);
  private snack = inject(MatSnackBar);
  private zone = inject(NgZone);

  private readonly timeoutMs = 30 * 60_000; // 30 minutes
  private readonly warnMs = 60_000;         // warn 1 minute before
  private lastActivity = Date.now();
  private timer?: ReturnType<typeof setInterval>;
  private warned = false;

  private onActivity = () => {
    this.lastActivity = Date.now();
    if (this.warned) this.zone.run(() => { this.warned = false; this.snack.dismiss(); });
  };

  start(): void {
    this.stop();
    this.lastActivity = Date.now();
    this.zone.runOutsideAngular(() => {
      EVENTS.forEach(e => document.addEventListener(e, this.onActivity, { passive: true }));
      this.timer = setInterval(() => this.check(), 5000);
    });
  }

  stop(): void {
    EVENTS.forEach(e => document.removeEventListener(e, this.onActivity));
    if (this.timer) clearInterval(this.timer);
    this.warned = false;
  }

  private check(): void {
    const idle = Date.now() - this.lastActivity;
    if (idle >= this.timeoutMs) {
      this.zone.run(() => { this.stop(); this.snack.dismiss(); this.auth.logout('idle'); });
    } else if (idle >= this.timeoutMs - this.warnMs && !this.warned) {
      this.zone.run(() => {
        this.warned = true;
        this.snack.open('You will be logged out in 1 minute due to inactivity.', 'Stay signed in', { duration: this.warnMs })
          .onAction().subscribe(() => this.onActivity());
      });
    }
  }
}
EOF

# ---------- login page ----------
cat > $A/pages/login/login.component.ts << 'EOF'
import { Component, inject } from '@angular/core';
import { NonNullableFormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { ActivatedRoute, Router } from '@angular/router';
import { HttpErrorResponse } from '@angular/common/http';
import { MatCardModule } from '@angular/material/card';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatButtonModule } from '@angular/material/button';
import { MatCheckboxModule } from '@angular/material/checkbox';
import { MatIconModule } from '@angular/material/icon';
import { AuthService } from '../../core/auth.service';

@Component({
  selector: 'app-login',
  imports: [ReactiveFormsModule, MatCardModule, MatFormFieldModule, MatInputModule,
            MatButtonModule, MatCheckboxModule, MatIconModule],
  template: `
  <div class="wrap">
    <mat-card class="card">
      <mat-card-header>
        <mat-card-title>Employee Management</mat-card-title>
        <mat-card-subtitle>Sign in to continue</mat-card-subtitle>
      </mat-card-header>
      <mat-card-content>
        @if (info) { <div class="msg info">{{ info }}</div> }
        @if (error) { <div class="msg error">{{ error }}</div> }

        <form [formGroup]="form" (ngSubmit)="submit()">
          <mat-form-field appearance="outline" class="full">
            <mat-label>Username</mat-label>
            <input matInput formControlName="username" autocomplete="username">
            @if (form.controls.username.hasError('required')) { <mat-error>Username is required</mat-error> }
            @if (form.controls.username.hasError('minlength')) { <mat-error>Minimum 3 characters</mat-error> }
          </mat-form-field>

          <mat-form-field appearance="outline" class="full">
            <mat-label>Password</mat-label>
            <input matInput [type]="hide ? 'password' : 'text'" formControlName="password" autocomplete="current-password">
            <button mat-icon-button matSuffix type="button" (click)="hide = !hide" [attr.aria-label]="hide ? 'Show password' : 'Hide password'">
              <mat-icon>{{ hide ? 'visibility' : 'visibility_off' }}</mat-icon>
            </button>
            @if (form.controls.password.hasError('required')) { <mat-error>Password is required</mat-error> }
            @if (form.controls.password.hasError('minlength')) { <mat-error>Minimum 6 characters</mat-error> }
          </mat-form-field>

          <mat-checkbox formControlName="remember">Remember me</mat-checkbox>

          <button mat-flat-button color="primary" class="full submit" type="submit" [disabled]="form.invalid || loading">
            {{ loading ? 'Signing in…' : 'Sign in' }}
          </button>
        </form>
        <p class="hint">Demo: admin / admin123 · user / user123</p>
      </mat-card-content>
    </mat-card>
  </div>`,
  styles: [`
    .wrap { min-height: 100vh; display: flex; align-items: center; justify-content: center; background: #f4f6f9; padding: 16px; }
    .card { width: 100%; max-width: 400px; padding: 8px; }
    form { display: flex; flex-direction: column; gap: 4px; margin-top: 16px; }
    .submit { margin-top: 16px; height: 44px; }
    .msg { padding: 10px 12px; border-radius: 6px; margin-top: 12px; font-size: 14px; }
    .info { background: #e8f0fe; color: #1a4fa0; }
    .error { background: #fdecea; color: #b3261e; }
    .hint { margin-top: 16px; font-size: 12px; color: #777; text-align: center; }
  `]
})
export class LoginComponent {
  private fb = inject(NonNullableFormBuilder);
  private auth = inject(AuthService);
  private router = inject(Router);
  private route = inject(ActivatedRoute);

  hide = true;
  loading = false;
  error = '';
  info = '';

  form = this.fb.group({
    username: [this.auth.rememberedUsername(), [Validators.required, Validators.minLength(3)]],
    password: ['', [Validators.required, Validators.minLength(6)]],
    remember: [!!this.auth.rememberedUsername()]
  });

  constructor() {
    const reason = this.route.snapshot.queryParamMap.get('reason');
    if (reason === 'idle') this.info = 'You were logged out due to inactivity.';
    if (reason === 'expired') this.info = 'Your session has expired. Please sign in again.';
  }

  submit(): void {
    if (this.form.invalid) return;
    this.loading = true;
    this.error = '';
    const { username, password, remember } = this.form.getRawValue();
    this.auth.login(username.trim(), password, remember).subscribe({
      next: () => this.router.navigate(['/employees']),
      error: (e: HttpErrorResponse) => {
        this.loading = false;
        this.error = e.status === 401 ? 'Invalid username or password' : 'Unable to sign in. Please try again.';
      }
    });
  }
}
EOF

# ---------- layout shell ----------
cat > $A/layout/shell.component.ts << 'EOF'
import { Component, OnDestroy, OnInit, inject } from '@angular/core';
import { RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';
import { MatToolbarModule } from '@angular/material/toolbar';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatMenuModule } from '@angular/material/menu';
import { AuthService } from '../core/auth.service';
import { IdleService } from '../core/idle.service';

@Component({
  selector: 'app-shell',
  imports: [RouterOutlet, RouterLink, RouterLinkActive, MatToolbarModule, MatButtonModule, MatIconModule, MatMenuModule],
  template: `
  <mat-toolbar color="primary" class="toolbar">
    <span class="brand">Employee Management</span>
    <nav>
      <a mat-button routerLink="/employees" routerLinkActive="active">Employees</a>
      @if (auth.isAdmin()) {
        <a mat-button routerLink="/reports" routerLinkActive="active">Reports</a>
      }
    </nav>
    <span class="spacer"></span>
    <button mat-button [matMenuTriggerFor]="menu">
      <mat-icon>account_circle</mat-icon>
      <span class="who">{{ auth.user()?.username }} ({{ auth.user()?.role }})</span>
    </button>
    <mat-menu #menu="matMenu">
      <button mat-menu-item (click)="logout()"><mat-icon>logout</mat-icon><span>Logout</span></button>
    </mat-menu>
  </mat-toolbar>
  <main class="content"><router-outlet /></main>`,
  styles: [`
    .toolbar { position: sticky; top: 0; z-index: 10; gap: 8px; }
    .brand { font-weight: 600; margin-right: 16px; }
    .spacer { flex: 1 1 auto; }
    nav a.active { background: rgba(255,255,255,.18); }
    .content { padding: 24px; max-width: 1280px; margin: 0 auto; }
    @media (max-width: 600px) { .brand { display: none; } .who { display: none; } .content { padding: 12px; } }
  `]
})
export class ShellComponent implements OnInit, OnDestroy {
  auth = inject(AuthService);
  private idle = inject(IdleService);

  ngOnInit(): void { this.idle.start(); }
  ngOnDestroy(): void { this.idle.stop(); }

  logout(): void { this.idle.stop(); this.auth.logout(); }
}
EOF

# ---------- placeholder pages (replaced in next steps) ----------
cat > $A/pages/employees/employee-list.component.ts << 'EOF'
import { Component } from '@angular/core';
@Component({ selector: 'app-employee-list', template: `<h2>Employees</h2><p>Coming next…</p>` })
export class EmployeeListComponent {}
EOF
cat > $A/pages/reports/report.component.ts << 'EOF'
import { Component } from '@angular/core';
@Component({ selector: 'app-report', template: `<h2>Reports</h2><p>Coming next…</p>` })
export class ReportComponent {}
EOF

# ---------- routes / config / root ----------
cat > $A/app.routes.ts << 'EOF'
import { Routes } from '@angular/router';
import { ShellComponent } from './layout/shell.component';
import { adminGuard, authGuard, loginGuard } from './core/auth.guards';

export const routes: Routes = [
  {
    path: 'login', canActivate: [loginGuard],
    loadComponent: () => import('./pages/login/login.component').then(m => m.LoginComponent)
  },
  {
    path: '', component: ShellComponent, canActivate: [authGuard], canActivateChild: [authGuard],
    children: [
      { path: 'employees', loadComponent: () => import('./pages/employees/employee-list.component').then(m => m.EmployeeListComponent) },
      { path: 'reports', canActivate: [adminGuard], loadComponent: () => import('./pages/reports/report.component').then(m => m.ReportComponent) },
      { path: '', pathMatch: 'full', redirectTo: 'employees' }
    ]
  },
  { path: '**', redirectTo: '' }
];
EOF

cat > $A/app.config.ts << 'EOF'
import { ApplicationConfig, provideZoneChangeDetection } from '@angular/core';
import { provideRouter } from '@angular/router';
import { provideHttpClient, withInterceptors } from '@angular/common/http';
import { provideAnimationsAsync } from '@angular/platform-browser/animations/async';
import { provideNativeDateAdapter } from '@angular/material/core';
import { routes } from './app.routes';
import { authInterceptor } from './core/auth.interceptor';

export const appConfig: ApplicationConfig = {
  providers: [
    provideZoneChangeDetection({ eventCoalescing: true }),
    provideRouter(routes),
    provideHttpClient(withInterceptors([authInterceptor])),
    provideAnimationsAsync(),
    provideNativeDateAdapter()
  ]
};
EOF

cat > $A/app.component.ts << 'EOF'
import { Component } from '@angular/core';
import { RouterOutlet } from '@angular/router';

@Component({ selector: 'app-root', imports: [RouterOutlet], template: `<router-outlet />` })
export class AppComponent {}
EOF

grep -q '.full {' src/styles.scss || cat >> src/styles.scss << 'EOF'

.full { width: 100%; }
EOF

# ---------- backend: reports are ADMIN-only (matches menu visibility) ----------
cd /workspaces/employee-mgmt-app/backend
python3 - << 'PYEOF'
p='src/main/java/com/raj/backend/config/SecurityConfig.java'; s=open(p).read()
if '/api/reports/**' not in s:
    s=s.replace('.hasRole("ADMIN")\n', '.hasRole("ADMIN")\n                .requestMatchers("/api/reports/**").hasRole("ADMIN")\n',1)
    open(p,'w').write(s)
PYEOF
echo "Done frontend-1"