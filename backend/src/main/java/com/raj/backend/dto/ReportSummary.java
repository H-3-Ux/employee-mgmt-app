package com.raj.backend.dto;

import java.math.BigDecimal;
import java.util.Map;

public record ReportSummary(
    long totalRecords,
    BigDecimal totalSalary,
    BigDecimal averageSalary,
    Map<String, Long> byStatus,
    Map<String, Long> byDepartment,
    Map<String, Long> byJoiningMonth
) {}
