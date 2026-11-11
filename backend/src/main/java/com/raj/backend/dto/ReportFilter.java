package com.raj.backend.dto;

import com.raj.backend.model.EmployeeStatus;
import org.springframework.format.annotation.DateTimeFormat;
import java.time.LocalDate;

public class ReportFilter {
    @DateTimeFormat(iso = DateTimeFormat.ISO.DATE)
    private LocalDate from;
    @DateTimeFormat(iso = DateTimeFormat.ISO.DATE)
    private LocalDate to;
    private EmployeeStatus status;
    private Long departmentId;

    public void validate() {
        if (from != null && to != null && from.isAfter(to))
            throw new IllegalArgumentException("'From' date must be on or before 'To' date");
    }

    public String periodLabel() {
        return (from == null ? "Start" : from.toString()) + " to " + (to == null ? "Today" : to.toString());
    }

    public LocalDate getFrom() { return from; }
    public void setFrom(LocalDate from) { this.from = from; }
    public LocalDate getTo() { return to; }
    public void setTo(LocalDate to) { this.to = to; }
    public EmployeeStatus getStatus() { return status; }
    public void setStatus(EmployeeStatus status) { this.status = status; }
    public Long getDepartmentId() { return departmentId; }
    public void setDepartmentId(Long departmentId) { this.departmentId = departmentId; }
}
