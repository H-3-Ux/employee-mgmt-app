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
