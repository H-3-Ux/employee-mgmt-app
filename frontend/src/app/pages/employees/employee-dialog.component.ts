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
