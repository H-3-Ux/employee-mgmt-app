package com.raj.backend.dto;

import com.raj.backend.model.Employee;
import com.raj.backend.model.EmployeeStatus;
import java.math.BigDecimal;
import java.time.LocalDate;

public record EmployeeResponse(
    Long id, String empCode, String name, String email, String phone,
    Long departmentId, String departmentName, String designation,
    BigDecimal salary, EmployeeStatus status, LocalDate joiningDate
) {
    public static EmployeeResponse from(Employee e) {
        return new EmployeeResponse(e.getId(), e.getEmpCode(), e.getName(), e.getEmail(), e.getPhone(),
            e.getDepartment().getId(), e.getDepartment().getName(), e.getDesignation(),
            e.getSalary(), e.getStatus(), e.getJoiningDate());
    }
}
