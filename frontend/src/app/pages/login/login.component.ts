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
