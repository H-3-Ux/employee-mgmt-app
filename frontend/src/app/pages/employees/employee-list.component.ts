import { Component, DestroyRef, OnInit, inject } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { DatePipe, DecimalPipe } from '@angular/common';
import { FormControl, ReactiveFormsModule } from '@angular/forms';
import { debounceTime, distinctUntilChanged } from 'rxjs';
import { MatTableModule } from '@angular/material/table';
import { MatPaginatorModule, PageEvent } from '@angular/material/paginator';
import { MatSortModule, Sort, SortDirection } from '@angular/material/sort';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatIconModule } from '@angular/material/icon';
import { MatButtonModule } from '@angular/material/button';
import { MatTooltipModule } from '@angular/material/tooltip';
import { MatProgressBarModule } from '@angular/material/progress-bar';
import { MatDialog } from '@angular/material/dialog';
import { MatSnackBar } from '@angular/material/snack-bar';
import { Department, Employee } from '../../core/models';
import { EmployeeService } from '../../core/employee.service';
import { AuthService } from '../../core/auth.service';
import { EmployeeDialogComponent } from './employee-dialog.component';
import { ConfirmDialogComponent } from '../../shared/confirm-dialog.component';

@Component({
  selector: 'app-employee-list',
  imports: [ReactiveFormsModule, DatePipe, DecimalPipe, MatTableModule, MatPaginatorModule, MatSortModule,
            MatFormFieldModule, MatInputModule, MatIconModule, MatButtonModule, MatTooltipModule, MatProgressBarModule],
  template: `
  <div class="header">
    <h2>Employees</h2>
    <span class="spacer"></span>
    <button mat-flat-button color="primary" (click)="openDialog()"><mat-icon>add</mat-icon> Add Employee</button>
  </div>

  <mat-form-field appearance="outline" class="search">
    <mat-label>Search by name, email or code</mat-label>
    <mat-icon matPrefix>search</mat-icon>
    <input matInput [formControl]="search">
    @if (search.value) {
      <button mat-icon-button matSuffix (click)="search.setValue('')" aria-label="Clear search"><mat-icon>close</mat-icon></button>
    }
  </mat-form-field>

  <div class="table-card">
    @if (loading) { <mat-progress-bar mode="indeterminate" /> }
    <div class="table-scroll">
      <table mat-table [dataSource]="rows" matSort (matSortChange)="onSort($event)">
        <ng-container matColumnDef="empCode">
          <th mat-header-cell *matHeaderCellDef mat-sort-header>Code</th>
          <td mat-cell *matCellDef="let e">{{ e.empCode }}</td>
        </ng-container>
        <ng-container matColumnDef="name">
          <th mat-header-cell *matHeaderCellDef mat-sort-header>Name</th>
          <td mat-cell *matCellDef="let e">{{ e.name }}</td>
        </ng-container>
        <ng-container matColumnDef="email">
          <th mat-header-cell *matHeaderCellDef mat-sort-header>Email</th>
          <td mat-cell *matCellDef="let e">{{ e.email }}</td>
        </ng-container>
        <ng-container matColumnDef="phone">
          <th mat-header-cell *matHeaderCellDef>Phone</th>
          <td mat-cell *matCellDef="let e">{{ e.phone }}</td>
        </ng-container>
        <ng-container matColumnDef="departmentName">
          <th mat-header-cell *matHeaderCellDef mat-sort-header>Department</th>
          <td mat-cell *matCellDef="let e">{{ e.departmentName }}</td>
        </ng-container>
        <ng-container matColumnDef="designation">
          <th mat-header-cell *matHeaderCellDef mat-sort-header>Designation</th>
          <td mat-cell *matCellDef="let e">{{ e.designation }}</td>
        </ng-container>
        <ng-container matColumnDef="salary">
          <th mat-header-cell *matHeaderCellDef mat-sort-header>Salary</th>
          <td mat-cell *matCellDef="let e" class="num">{{ e.salary | number:'1.2-2' }}</td>
        </ng-container>
        <ng-container matColumnDef="status">
          <th mat-header-cell *matHeaderCellDef mat-sort-header>Status</th>
          <td mat-cell *matCellDef="let e"><span class="status" [class]="e.status">{{ e.status.replace('_', ' ') }}</span></td>
        </ng-container>
        <ng-container matColumnDef="joiningDate">
          <th mat-header-cell *matHeaderCellDef mat-sort-header>Joined</th>
          <td mat-cell *matCellDef="let e">{{ e.joiningDate | date:'dd MMM yyyy' }}</td>
        </ng-container>
        <ng-container matColumnDef="actions">
          <th mat-header-cell *matHeaderCellDef></th>
          <td mat-cell *matCellDef="let e" class="actions">
            <button mat-icon-button matTooltip="Edit" (click)="$event.stopPropagation(); openDialog(e)"><mat-icon>edit</mat-icon></button>
            @if (auth.isAdmin()) {
              <button mat-icon-button matTooltip="Delete" (click)="$event.stopPropagation(); confirmDelete(e)"><mat-icon>delete</mat-icon></button>
            }
          </td>
        </ng-container>

        <tr mat-header-row *matHeaderRowDef="columns; sticky: true"></tr>
        <tr mat-row *matRowDef="let row; columns: columns" class="clickable" (click)="openDialog(row)"></tr>
        <tr class="mat-row" *matNoDataRow>
          <td class="mat-cell no-data" [attr.colspan]="columns.length">{{ loading ? 'Loading…' : 'No employees found' }}</td>
        </tr>
      </table>
    </div>
    <mat-paginator [length]="total" [pageIndex]="pageIndex" [pageSize]="pageSize"
                   [pageSizeOptions]="[5, 10, 25]" (page)="onPage($event)" showFirstLastButtons />
  </div>`,
  styles: [`
    .header { display: flex; align-items: center; margin-bottom: 8px; }
    .spacer { flex: 1 1 auto; }
    .search { width: 100%; max-width: 420px; }
    .table-card { background: #fff; border-radius: 8px; box-shadow: 0 1px 3px rgba(0,0,0,.12); overflow: hidden; }
    .table-scroll { overflow-x: auto; }
    table { width: 100%; min-width: 1000px; }
    .clickable { cursor: pointer; }
    .clickable:hover { background: #f5f7fb; }
    .num { text-align: right; padding-right: 24px; }
    .actions { white-space: nowrap; text-align: right; }
    .no-data { padding: 24px; text-align: center; color: #777; }
    .status { padding: 2px 10px; border-radius: 12px; font-size: 12px; font-weight: 500; white-space: nowrap; }
    .status.ACTIVE { background: #e6f4ea; color: #1e7e34; }
    .status.INACTIVE { background: #f1f3f4; color: #5f6368; }
    .status.ON_LEAVE { background: #fff4e5; color: #b26a00; }
  `]
})
export class EmployeeListComponent implements OnInit {
  private svc = inject(EmployeeService);
  private dialog = inject(MatDialog);
  private snack = inject(MatSnackBar);
  private destroyRef = inject(DestroyRef);
  auth = inject(AuthService);

  columns = ['empCode', 'name', 'email', 'phone', 'departmentName', 'designation', 'salary', 'status', 'joiningDate', 'actions'];
  rows: Employee[] = [];
  departments: Department[] = [];
  total = 0;
  pageIndex = 0;
  pageSize = 10;
  sortField = '';
  sortDir: SortDirection = '';
  loading = false;
  search = new FormControl('', { nonNullable: true });

  ngOnInit(): void {
    this.svc.departments().subscribe(d => this.departments = d);
    this.search.valueChanges
      .pipe(debounceTime(300), distinctUntilChanged(), takeUntilDestroyed(this.destroyRef))
      .subscribe(() => { this.pageIndex = 0; this.load(); });
    this.load();
  }

  load(): void {
    this.loading = true;
    const field = this.sortField === 'departmentName' ? 'department.name' : this.sortField;
    this.svc.list(this.search.value.trim(), this.pageIndex, this.pageSize, field, this.sortDir).subscribe({
      next: page => { this.rows = page.content; this.total = page.totalElements; this.loading = false; },
      error: () => { this.loading = false; this.snack.open('Failed to load employees', 'Close', { duration: 4000 }); }
    });
  }

  onSort(s: Sort): void {
    this.sortField = s.direction ? s.active : '';
    this.sortDir = s.direction;
    this.pageIndex = 0;
    this.load();
  }

  onPage(e: PageEvent): void {
    this.pageIndex = e.pageIndex;
    this.pageSize = e.pageSize;
    this.load();
  }

  openDialog(employee?: Employee): void {
    this.dialog.open(EmployeeDialogComponent, {
      width: '720px', maxWidth: '95vw', disableClose: true,
      data: { employee, departments: this.departments }
    }).afterClosed().subscribe(saved => {
      if (saved) {
        this.snack.open(employee ? 'Employee updated' : 'Employee added', 'OK', { duration: 3000 });
        this.load();
      }
    });
  }

  confirmDelete(e: Employee): void {
    this.dialog.open(ConfirmDialogComponent, {
      data: { title: 'Delete employee', message: `Delete ${e.name} (${e.empCode})?`, confirmText: 'Delete' }
    }).afterClosed().subscribe(ok => {
      if (!ok) return;
      this.svc.delete(e.id).subscribe({
        next: () => {
          this.snack.open('Employee deleted', 'OK', { duration: 3000 });
          if (this.rows.length === 1 && this.pageIndex > 0) this.pageIndex--;
          this.load();
        },
        error: err => this.snack.open(err.status === 403 ? 'You are not allowed to delete' : 'Delete failed', 'Close', { duration: 4000 })
      });
    });
  }
}
