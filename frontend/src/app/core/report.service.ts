import { Injectable, inject } from '@angular/core';
import { HttpClient, HttpParams, HttpResponse } from '@angular/common/http';
import { Observable } from 'rxjs';
import { Employee, Page, ReportSummary } from './models';

export interface ReportFilterValue {
  from: string | null; to: string | null; status: string | null; departmentId: number | null;
}

@Injectable({ providedIn: 'root' })
export class ReportService {
  private http = inject(HttpClient);
  private base = '/api/reports';

  private params(f: ReportFilterValue): HttpParams {
    let p = new HttpParams();
    if (f.from) p = p.set('from', f.from);
    if (f.to) p = p.set('to', f.to);
    if (f.status) p = p.set('status', f.status);
    if (f.departmentId != null) p = p.set('departmentId', f.departmentId);
    return p;
  }

  summary(f: ReportFilterValue): Observable<ReportSummary> {
    return this.http.get<ReportSummary>(`${this.base}/summary`, { params: this.params(f) });
  }

  list(f: ReportFilterValue, page: number, size: number, sort: string, dir: string): Observable<Page<Employee>> {
    let p = this.params(f).set('page', page).set('size', size);
    if (sort && dir) p = p.set('sort', `${sort},${dir}`);
    return this.http.get<Page<Employee>>(`${this.base}/employees`, { params: p });
  }

  export(type: 'excel' | 'pdf', f: ReportFilterValue): Observable<HttpResponse<Blob>> {
    return this.http.get(`${this.base}/export/${type}`, { params: this.params(f), responseType: 'blob', observe: 'response' });
  }
}
