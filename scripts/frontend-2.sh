#!/bin/bash
set -e
cd /workspaces/employee-mgmt-app/frontend
A=src/app

# ---------- employee service ----------
cat > $A/core/employee.service.ts << 'EOF'
import { Injectable, inject } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { Department, Employee, EmployeeRequest, Page } from './models';

@Injectable({ providedIn: 'root' })
export class EmployeeService {
  private http = inject(HttpClient);
  private base = '/api/employees';

  list(q: string, page: number, size: number, sort: string, dir: string): Observable<Page<Employee>> {
    let params = new HttpParams().set('q', q).set('page', page).set('size', size);
    if (sort && dir) params = params.set('sort', `${sort},${dir}`);
    return this.http.get<Page<Employee>>(this.base, { params });
  }
  create(req: EmployeeRequest): Observable<Employee> { return this.http.post<Employee>(this.base, req); }
  update(id: number, req: EmployeeRequest): Observable<Employee> { return this.http.put<Employee>(`${this.base}/${id}`, req); }
  delete(id: number): Observable<void> { return this.http.delete<void>(`${this.base}/${id}`); }
  departments(): Observable<Department[]> { return this.http.get<Department[]>('/api/departments'); }
}
EOF

# ---------- confirm dialog ----------
cat > $A/shared/confirm-dialog.component.ts << 'EOF'
import { Component, inject } from '@angular/core';
import { MAT_DIALOG_DATA, MatDialogModule } from '@angular/material/dialog';
import { MatButtonModule } from '@angular/material/button';

export interface ConfirmData { title: string; message: string; confirmText?: string; }

@Component({
  selector: 'app-confirm-dialog',
  imports: [MatDialogModule, MatButtonModule],
  template: `
    <h2 mat-dialog-title>{{ data.title }}</h2>
    <mat-dialog-content>{{ data.message }}</mat-dialog-content>
    <mat-dialog-actions align="end">
      <button mat-button [mat-dialog-close]="false">Cancel</button>
      <button mat-flat-button class="danger" [mat-dialog-close]="true">{{ data.confirmText ?? 'Confirm' }}</button>
    </mat-dialog-actions>`,
  styles: [`.danger { background: #b3261e; color: #fff; }`]
})
export class ConfirmDialogComponent {
  data = inject<ConfirmData>(MAT_DIALOG_DATA);
}
EOF

# ---------- add / edit dialog ----------
cat > $A/pages/employees/employee-dialog.component.ts << 'EOF'
import { Component, inject } from '@angular/core';
import { AbstractControl, FormBuilder, ReactiveFormsModule, ValidationErrors, Validators } from '@angular/forms';
import { HttpErrorResponse } from '@angular/common/http';
import { MAT_DIALOG_DATA, MatDialogModule, MatDialogRef } from '@angular/material/dialog';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatSelectModule } from '@angular/material/select';
import { MatDatepickerModule } from '@angular/material/datepicker';
import { MatButtonModule } from '@angular/material/button';
import { Department, Employee, EmployeeRequest, EmployeeStatus, STATUSES, toIsoDate } from '../../core/models';
import { EmployeeService } from '../../core/employee.service';

export interface EmployeeDialogData { employee?: Employee; departments: Department[]; }

/** Custom validator: rejects whitespace-only text. */
function notBlank(c: AbstractControl): ValidationErrors | null {
  return typeof c.value === 'string' && c.value.length > 0 && c.value.trim().length === 0 ? { blank: true } : null;
}

/** Custom validator: date must not be in the future. */
function notFuture(c: AbstractControl): ValidationErrors | null {
  const v = c.value as Date | null;
  if (!v) return null;
  const endOfToday = new Date();
  endOfToday.setHours(23, 59, 59, 999);
  return v > endOfToday ? { future: true } : null;
}

function parseDate(s?: string): Date | null {
  if (!s) return null;
  const [y, m, d] = s.split('-').map(Number);
  return new Date(y, m - 1, d);
}

@Component({
  selector: 'app-employee-dialog',
  imports: [ReactiveFormsModule, MatDialogModule, MatFormFieldModule, MatInputModule,
            MatSelectModule, MatDatepickerModule, MatButtonModule],
  template: `
  <h2 mat-dialog-title>{{ isEdit ? 'Edit Employee' : 'Add Employee' }}</h2>
  <mat-dialog-content>
    @if (serverError) { <div class="server-error">{{ serverError }}</div> }
    <form [formGroup]="form" class="grid" (ngSubmit)="save()" id="empForm">
      <mat-form-field appearance="outline">
        <mat-label>Employee Code</mat-label>
        <input matInput formControlName="empCode" maxlength="20">
        <mat-error>{{ errorOf('empCode') }}</mat-error>
      </mat-form-field>

      <mat-form-field appearance="outline">
        <mat-label>Full Name</mat-label>
        <input matInput formControlName="name" maxlength="100">
        <mat-error>{{ errorOf('name') }}</mat-error>
      </mat-form-field>

      <mat-form-field appearance="outline">
        <mat-label>Email</mat-label>
        <input matInput type="email" formControlName="email" maxlength="100">
        <mat-error>{{ errorOf('email') }}</mat-error>
      </mat-form-field>

      <mat-form-field appearance="outline">
        <mat-label>Phone</mat-label>
        <input matInput formControlName="phone" maxlength="10" inputmode="numeric">
        <mat-error>{{ errorOf('phone') }}</mat-error>
      </mat-form-field>

      <mat-form-field appearance="outline">
        <mat-label>Department</mat-label>
        <mat-select formControlName="departmentId">
          @for (d of data.departments; track d.id) { <mat-option [value]="d.id">{{ d.name }}</mat-option> }
        </mat-select>
        <mat-error>{{ errorOf('departmentId') }}</mat-error>
      </mat-form-field>

      <mat-form-field appearance="outline">
        <mat-label>Designation</mat-label>
        <input matInput formControlName="designation" maxlength="50">
        <mat-error>{{ errorOf('designation') }}</mat-error>
      </mat-form-field>

      <mat-form-field appearance="outline">
        <mat-label>Salary</mat-label>
        <input matInput type="number" formControlName="salary" min="1">
        <mat-error>{{ errorOf('salary') }}</mat-error>
      </mat-form-field>

      <mat-form-field appearance="outline">
        <mat-label>Status</mat-label>
        <mat-select formControlName="status">
          @for (s of statuses; track s) { <mat-option [value]="s">{{ s.replace('_', ' ') }}</mat-option> }
        </mat-select>
        <mat-error>{{ errorOf('status') }}</mat-error>
      </mat-form-field>

      <mat-form-field appearance="outline">
        <mat-label>Joining Date</mat-label>
        <input matInput [matDatepicker]="picker" formControlName="joiningDate" [max]="today">
        <mat-datepicker-toggle matIconSuffix [for]="picker" />
        <mat-datepicker #picker />
        <mat-error>{{ errorOf('joiningDate') }}</mat-error>
      </mat-form-field>
    </form>
  </mat-dialog-content>
  <mat-dialog-actions align="end">
    <button mat-button type="button" (click)="ref.close(false)" [disabled]="saving">Cancel</button>
    <button mat-flat-button color="primary" type="submit" form="empForm" [disabled]="saving">
      {{ saving ? 'Saving…' : (isEdit ? 'Update' : 'Save') }}
    </button>
  </mat-dialog-actions>`,
  styles: [`
    .grid { display: grid; grid-template-columns: 1fr 1fr; column-gap: 16px; padding-top: 8px; }
    @media (max-width: 600px) { .grid { grid-template-columns: 1fr; } }
    .server-error { background: #fdecea; color: #b3261e; padding: 10px 12px; border-radius: 6px; margin-bottom: 12px; }
  `]
})
export class EmployeeDialogComponent {
  data = inject<EmployeeDialogData>(MAT_DIALOG_DATA);
  ref = inject(MatDialogRef<EmployeeDialogComponent>);
  private fb = inject(FormBuilder);
  private svc = inject(EmployeeService);

  statuses = STATUSES;
  today = new Date();
  isEdit = !!this.data.employee;
  saving = false;
  serverError = '';

  form = this.fb.group({
    empCode: [this.data.employee?.empCode ?? '', [Validators.required, Validators.maxLength(20), Validators.pattern(/^[A-Za-z0-9-]+$/)]],
    name: [this.data.employee?.name ?? '', [Validators.required, Validators.minLength(2), Validators.maxLength(100), notBlank]],
    email: [this.data.employee?.email ?? '', [Validators.required, Validators.email, Validators.maxLength(100)]],
    phone: [this.data.employee?.phone ?? '', [Validators.required, Validators.pattern(/^[0-9]{10}$/)]],
    departmentId: [this.data.employee?.departmentId ?? null as number | null, Validators.required],
    designation: [this.data.employee?.designation ?? '', [Validators.required, Validators.maxLength(50), notBlank]],
    salary: [this.data.employee?.salary ?? null as number | null, [Validators.required, Validators.min(1)]],
    status: [this.data.employee?.status ?? 'ACTIVE' as EmployeeStatus, Validators.required],
    joiningDate: [parseDate(this.data.employee?.joiningDate) ?? new Date(), [Validators.required, notFuture]]
  });

  errorOf(name: string): string {
    const e = this.form.get(name)?.errors;
    if (!e) return '';
    if (e['server']) return e['server'];
    if (e['required']) return 'This field is required';
    if (e['email']) return 'Enter a valid email address';
    if (e['minlength']) return `Minimum ${e['minlength'].requiredLength} characters`;
    if (e['maxlength']) return `Maximum ${e['maxlength'].requiredLength} characters`;
    if (e['pattern']) return name === 'phone' ? 'Phone must be exactly 10 digits' : 'Only letters, numbers and hyphen allowed';
    if (e['min']) return 'Must be greater than 0';
    if (e['blank']) return 'Cannot be blank';
    if (e['future']) return 'Joining date cannot be in the future';
    if (e['matDatepickerParse']) return 'Enter a valid date';
    if (e['matDatepickerMax']) return 'Joining date cannot be in the future';
    return 'Invalid value';
  }

  save(): void {
    if (this.form.invalid) { this.form.markAllAsTouched(); return; }
    const v = this.form.getRawValue();
    const req: EmployeeRequest = {
      empCode: v.empCode!.trim(),
      name: v.name!.trim(),
      email: v.email!.trim(),
      phone: v.phone!.trim(),
      departmentId: v.departmentId!,
      designation: v.designation!.trim(),
      salary: Number(v.salary),
      status: v.status!,
      joiningDate: toIsoDate(v.joiningDate)!
    };
    this.saving = true;
    this.serverError = '';
    const call = this.data.employee ? this.svc.update(this.data.employee.id, req) : this.svc.create(req);
    call.subscribe({
      next: () => this.ref.close(true),
      error: (e: HttpErrorResponse) => {
        this.saving = false;
        const msg: string = e.error?.message ?? 'Save failed. Please try again.';
        if (e.status === 409) {
          if (/email/i.test(msg)) this.setServerError('email', msg);
          else if (/code/i.test(msg)) this.setServerError('empCode', msg);
          else this.serverError = msg;
        } else if (e.status === 400 && e.error?.errors) {
          Object.entries(e.error.errors).forEach(([field, m]) => this.setServerError(field, String(m)));
        } else {
          this.serverError = msg;
        }
      }
    });
  }

  private setServerError(field: string, msg: string): void {
    const c = this.form.get(field);
    if (c) { c.setErrors({ ...(c.errors ?? {}), server: msg }); c.markAsTouched(); }
    else this.serverError = msg;
  }
}
EOF

# ---------- list page ----------
cat > $A/pages/employees/employee-list.component.ts << 'EOF'
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
EOF

# ---------- toolbar tweak for Material 3 light toolbar ----------
sed -i 's/nav a.active { background: rgba(255,255,255,.18); }/nav a.active { background: rgba(0,0,0,.08); }\n    .toolbar { border-bottom: 1px solid #e0e0e0; }/' $A/layout/shell.component.ts
echo "Done frontend-2"
