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
