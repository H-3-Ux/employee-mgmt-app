import { Component, DestroyRef, OnInit, inject } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { DatePipe, DecimalPipe } from '@angular/common';
import { FormBuilder, ReactiveFormsModule } from '@angular/forms';
import { debounceTime } from 'rxjs';
import { MatTableModule } from '@angular/material/table';
import { MatPaginatorModule, PageEvent } from '@angular/material/paginator';
import { MatSortModule, Sort, SortDirection } from '@angular/material/sort';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatSelectModule } from '@angular/material/select';
import { MatDatepickerModule } from '@angular/material/datepicker';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatProgressBarModule } from '@angular/material/progress-bar';
import { MatSnackBar } from '@angular/material/snack-bar';
import { Department, Employee, ReportSummary, STATUSES, toIsoDate } from '../../core/models';
import { ReportFilterValue, ReportService } from '../../core/report.service';
import { EmployeeService } from '../../core/employee.service';

function startOfMonth(): Date { const d = new Date(); return new Date(d.getFullYear(), d.getMonth(), 1); }
function today(): Date { const d = new Date(); return new Date(d.getFullYear(), d.getMonth(), d.getDate()); }

@Component({
  selector: 'app-report',
  imports: [ReactiveFormsModule, DatePipe, DecimalPipe, MatTableModule, MatPaginatorModule, MatSortModule,
            MatFormFieldModule, MatInputModule, MatSelectModule, MatDatepickerModule, MatButtonModule,
            MatIconModule, MatProgressBarModule],
  template: `
  <div class="header">
    <h2>Employee Report</h2>
    <span class="spacer"></span>
    <button mat-stroked-button (click)="export('excel')" [disabled]="!!exporting || rangeInvalid()">
      <mat-icon>table_view</mat-icon> {{ exporting === 'excel' ? 'Exporting…' : 'Export Excel' }}
    </button>
    <button mat-stroked-button (click)="export('pdf')" [disabled]="!!exporting || rangeInvalid()">
      <mat-icon>picture_as_pdf</mat-icon> {{ exporting === 'pdf' ? 'Exporting…' : 'Export PDF' }}
    </button>
  </div>

  <form [formGroup]="filters" class="filters">
    <mat-form-field appearance="outline">
      <mat-label>Joining date range</mat-label>
      <mat-date-range-input formGroupName="range" [rangePicker]="rp">
        <input matStartDate formControlName="from" placeholder="From">
        <input matEndDate formControlName="to" placeholder="To">
      </mat-date-range-input>
      <mat-datepicker-toggle matIconSuffix [for]="rp" />
      <mat-date-range-picker #rp />
      @if (rangeInvalid()) { <mat-hint class="err">'From' must be on or before 'To'</mat-hint> }
      
    </mat-form-field>

    <mat-form-field appearance="outline" floatLabel="always">
      <mat-label>Status</mat-label>
      <mat-select formControlName="status">
        <mat-option value="">All</mat-option>
        @for (s of statuses; track s) { <mat-option [value]="s">{{ s.replace('_', ' ') }}</mat-option> }
      </mat-select>
    </mat-form-field>

    <mat-form-field appearance="outline" floatLabel="always">
      <mat-label>Department</mat-label>
      <mat-select formControlName="departmentId">
        <mat-option [value]="null">All</mat-option>
        @for (d of departments; track d.id) { <mat-option [value]="d.id">{{ d.name }}</mat-option> }
      </mat-select>
    </mat-form-field>

    <button mat-button type="button" (click)="reset()"><mat-icon>restart_alt</mat-icon> Reset</button>
  </form>

  <div class="cards">
    <div class="card">
      <div class="label">Total Employees</div>
      <div class="value">{{ summary?.totalRecords ?? 0 }}</div>
    </div>
    <div class="card">
      <div class="label">Total Salary</div>
      <div class="value">{{ (summary?.totalSalary ?? 0) | number:'1.0-0' }}</div>
    </div>
    <div class="card">
      <div class="label">Average Salary</div>
      <div class="value">{{ (summary?.averageSalary ?? 0) | number:'1.0-0' }}</div>
    </div>
    <div class="card list">
      <div class="label">By Status</div>
      @for (s of entries(summary?.byStatus); track s[0]) {
        <div class="row"><span class="status" [class]="s[0]">{{ s[0].replace('_', ' ') }}</span><b>{{ s[1] }}</b></div>
      } @empty { <div class="muted">No data</div> }
    </div>
    <div class="card list">
      <div class="label">By Department</div>
      @for (d of entries(summary?.byDepartment); track d[0]) {
        <div class="row"><span>{{ d[0] }}</span><b>{{ d[1] }}</b></div>
      } @empty { <div class="muted">No data</div> }
    </div>
    <div class="card list">
      <div class="label">Joined by Month</div>
      @for (m of entries(summary?.byJoiningMonth); track m[0]) {
        <div class="row"><span>{{ m[0] }}</span><b>{{ m[1] }}</b></div>
      } @empty { <div class="muted">No data</div> }
    </div>
  </div>

  <div class="table-card">
    @if (loading) { <mat-progress-bar mode="indeterminate" /> }
    <div class="table-scroll">
      <table mat-table [dataSource]="rows" matSort matSortActive="joiningDate" matSortDirection="desc" (matSortChange)="onSort($event)">
        <ng-container matColumnDef="empCode">
          <th mat-header-cell *matHeaderCellDef mat-sort-header>Code</th>
          <td mat-cell *matCellDef="let e">{{ e.empCode }}</td>
        </ng-container>
        <ng-container matColumnDef="name">
          <th mat-header-cell *matHeaderCellDef mat-sort-header>Name</th>
          <td mat-cell *matCellDef="let e">{{ e.name }}</td>
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

        <tr mat-header-row *matHeaderRowDef="columns"></tr>
        <tr mat-row *matRowDef="let row; columns: columns"></tr>
        <tr class="mat-row" *matNoDataRow>
          <td class="mat-cell no-data" [attr.colspan]="columns.length">{{ loading ? 'Loading…' : 'No records for the selected filters' }}</td>
        </tr>
      </table>
    </div>
    <mat-paginator [length]="total" [pageIndex]="pageIndex" [pageSize]="pageSize"
                   [pageSizeOptions]="[5, 10, 25]" (page)="onPage($event)" showFirstLastButtons />
  </div>`,
  styles: [`
    .header { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; margin-bottom: 8px; }
    .spacer { flex: 1 1 auto; }
    .filters { display: flex; gap: 12px; flex-wrap: wrap; align-items: flex-start; }
    .filters mat-form-field { min-width: 200px; }
    .filters mat-form-field:first-child { min-width: 280px; }
    .filters button { margin-top: 10px; }
    .err { color: #b3261e; }
    .cards { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: 12px; margin: 16px 0; }
    .card { background: #fff; border-radius: 8px; box-shadow: 0 1px 3px rgba(0,0,0,.12); padding: 14px 16px; }
    .label { font-size: 12px; text-transform: uppercase; letter-spacing: .5px; color: #666; margin-bottom: 6px; }
    .value { font-size: 26px; font-weight: 600; }
    .list .row { display: flex; justify-content: space-between; align-items: center; padding: 3px 0; font-size: 14px; }
    .muted { color: #999; font-size: 13px; }
    .table-card { background: #fff; border-radius: 8px; box-shadow: 0 1px 3px rgba(0,0,0,.12); overflow: hidden; }
    .table-scroll { overflow-x: auto; }
    table { width: 100%; min-width: 760px; }
    td, th { white-space: nowrap; }
    .num { text-align: right; padding-right: 24px; }
    .no-data { padding: 24px; text-align: center; color: #777; }
    .status { padding: 2px 10px; border-radius: 12px; font-size: 12px; font-weight: 500; white-space: nowrap; }
    .status.ACTIVE { background: #e6f4ea; color: #1e7e34; }
    .status.INACTIVE { background: #f1f3f4; color: #5f6368; }
    .status.ON_LEAVE { background: #fff4e5; color: #b26a00; }
  `]
})
export class ReportComponent implements OnInit {
  private svc = inject(ReportService);
  private empSvc = inject(EmployeeService);
  private snack = inject(MatSnackBar);
  private fb = inject(FormBuilder);
  private destroyRef = inject(DestroyRef);

  statuses = STATUSES;
  departments: Department[] = [];
  columns = ['empCode', 'name', 'departmentName', 'designation', 'salary', 'status', 'joiningDate'];
  rows: Employee[] = [];
  summary: ReportSummary | null = null;
  total = 0;
  pageIndex = 0;
  pageSize = 10;
  sortField = 'joiningDate';
  sortDir: SortDirection = 'desc';
  loading = false;
  exporting: 'excel' | 'pdf' | null = null;

  filters = this.fb.group({
    range: this.fb.group({ from: [startOfMonth() as Date | null], to: [today() as Date | null] }),
    status: [''],
    departmentId: [null as number | null]
  });

  ngOnInit(): void {
    this.empSvc.departments().subscribe(d => this.departments = d);
    this.filters.valueChanges
      .pipe(debounceTime(300), takeUntilDestroyed(this.destroyRef))
      .subscribe(() => { this.pageIndex = 0; this.refresh(); });
    this.refresh();
  }

  entries(obj?: Record<string, number>): [string, number][] {
    return Object.entries(obj ?? {});
  }

  rangeInvalid(): boolean {
    const { from, to } = this.filters.controls.range.getRawValue();
    return !!from && !!to && from > to;
  }

  private filterValue(): ReportFilterValue {
    const v = this.filters.getRawValue();
    return {
      from: toIsoDate(v.range.from),
      to: toIsoDate(v.range.to),
      status: v.status || null,
      departmentId: v.departmentId
    };
  }

  refresh(): void {
    if (this.rangeInvalid()) return;
    const f = this.filterValue();
    this.svc.summary(f).subscribe({
      next: s => this.summary = s,
      error: () => this.snack.open('Failed to load summary', 'Close', { duration: 4000 })
    });
    this.loadTable();
  }

  private loadTable(): void {
    this.loading = true;
    const field = this.sortField === 'departmentName' ? 'department.name' : this.sortField;
    this.svc.list(this.filterValue(), this.pageIndex, this.pageSize, field, this.sortDir).subscribe({
      next: p => { this.rows = p.content; this.total = p.totalElements; this.loading = false; },
      error: () => { this.loading = false; this.snack.open('Failed to load report', 'Close', { duration: 4000 }); }
    });
  }

  onSort(s: Sort): void {
    this.sortField = s.direction ? s.active : '';
    this.sortDir = s.direction;
    this.pageIndex = 0;
    this.loadTable();
  }

  onPage(e: PageEvent): void {
    this.pageIndex = e.pageIndex;
    this.pageSize = e.pageSize;
    this.loadTable();
  }

  reset(): void {
    this.filters.reset({ range: { from: startOfMonth(), to: today() }, status: '', departmentId: null });
  }

  export(type: 'excel' | 'pdf'): void {
    if (this.rangeInvalid()) return;
    this.exporting = type;
    this.svc.export(type, this.filterValue()).subscribe({
      next: res => {
        const cd = res.headers.get('Content-Disposition') ?? '';
        const match = /filename="?([^"]+)"?/.exec(cd);
        const name = match?.[1] ?? `employee-report.${type === 'excel' ? 'xlsx' : 'pdf'}`;
        const url = URL.createObjectURL(res.body!);
        const a = document.createElement('a');
        a.href = url;
        a.download = name;
        a.click();
        setTimeout(() => URL.revokeObjectURL(url), 1000);
        this.exporting = null;
      },
      error: () => { this.exporting = null; this.snack.open('Export failed', 'Close', { duration: 4000 }); }
    });
  }
}
