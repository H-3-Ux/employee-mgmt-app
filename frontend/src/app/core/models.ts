export interface LoginResponse { token: string; username: string; role: 'ADMIN' | 'USER'; }
export interface Department { id: number; name: string; }
export type EmployeeStatus = 'ACTIVE' | 'INACTIVE' | 'ON_LEAVE';
export interface Employee {
  id: number; empCode: string; name: string; email: string; phone: string;
  departmentId: number; departmentName: string; designation: string;
  salary: number; status: EmployeeStatus; joiningDate: string;
}
export type EmployeeRequest = Omit<Employee, 'id' | 'departmentName'>;
export interface Page<T> { content: T[]; page: number; size: number; totalElements: number; totalPages: number; }
export interface ReportSummary {
  totalRecords: number; totalSalary: number; averageSalary: number;
  byStatus: Record<string, number>; byDepartment: Record<string, number>; byJoiningMonth: Record<string, number>;
}
export const STATUSES: EmployeeStatus[] = ['ACTIVE', 'INACTIVE', 'ON_LEAVE'];

/** Formats a Date as yyyy-MM-dd in local time (avoids UTC shift of toISOString). */
export function toIsoDate(d: Date | null | undefined): string | null {
  if (!d) return null;
  const p = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}
