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
