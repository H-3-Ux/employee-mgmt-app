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
