package com.raj.backend.service;

import com.raj.backend.dto.*;
import com.raj.backend.model.Employee;
import com.raj.backend.repository.ReportRepository;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Service
@Transactional(readOnly = true)
public class ReportService {
    private final ReportRepository repo;

    public ReportService(ReportRepository repo) { this.repo = repo; }

    public PageResponse<EmployeeResponse> list(ReportFilter f, Pageable pageable) {
        f.validate();
        return PageResponse.of(repo.findPage(f.getFrom(), f.getTo(), f.getStatus(), f.getDepartmentId(), pageable)
            .map(EmployeeResponse::from));
    }

    public List<Employee> allForExport(ReportFilter f) {
        f.validate();
        return repo.findAllFiltered(f.getFrom(), f.getTo(), f.getStatus(), f.getDepartmentId(),
            Sort.by(Sort.Direction.DESC, "joiningDate"));
    }

    public ReportSummary summary(ReportFilter f) {
        f.validate();
        var from = f.getFrom(); var to = f.getTo(); var st = f.getStatus(); var d = f.getDepartmentId();

        Object[] t = repo.totals(from, to, st, d).get(0);
        long count = ((Number) t[0]).longValue();
        BigDecimal sum = toMoney(t[1]);
        BigDecimal avg = toMoney(t[2]);

        Map<String, Long> byStatus = new LinkedHashMap<>();
        repo.countByStatus(from, to, st, d).forEach(r -> byStatus.put(r[0].toString(), ((Number) r[1]).longValue()));

        Map<String, Long> byDept = new LinkedHashMap<>();
        repo.countByDepartment(from, to, st, d).forEach(r -> byDept.put(r[0].toString(), ((Number) r[1]).longValue()));

        Map<String, Long> byMonth = new LinkedHashMap<>();
        repo.countByMonth(from, to, st, d).forEach(r -> byMonth.put(
            String.format("%04d-%02d", ((Number) r[0]).intValue(), ((Number) r[1]).intValue()),
            ((Number) r[2]).longValue()));

        return new ReportSummary(count, sum, avg, byStatus, byDept, byMonth);
    }

    private BigDecimal toMoney(Object o) {
        return o == null ? BigDecimal.ZERO.setScale(2) : new BigDecimal(o.toString()).setScale(2, RoundingMode.HALF_UP);
    }
}
