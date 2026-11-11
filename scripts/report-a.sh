cd /workspaces/employee-mgmt-app/backend
B=src/main/java/com/raj/backend

python3 - << 'EOF'
p='pom.xml'; s=open(p).read()
deps='''<dependencies>
		<dependency><groupId>org.apache.poi</groupId><artifactId>poi-ooxml</artifactId><version>5.2.5</version></dependency>
		<dependency><groupId>com.github.librepdf</groupId><artifactId>openpdf</artifactId><version>1.3.30</version></dependency>'''
open(p,'w').write(s.replace('<dependencies>',deps,1))

p='src/main/java/com/raj/backend/exception/GlobalExceptionHandler.java'; s=open(p).read()
h='''
    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<Map<String, Object>> illegalArg(IllegalArgumentException ex) {
        return ResponseEntity.badRequest().body(Map.of("message", ex.getMessage()));
    }
}
'''
i=s.rstrip().rfind('}'); open(p,'w').write(s[:i]+h)
EOF

cat > $B/dto/ReportFilter.java << 'EOF'
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
EOF

cat > $B/dto/ReportSummary.java << 'EOF'
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
EOF

cat > $B/repository/ReportRepository.java << 'EOF'
package com.raj.backend.repository;

import com.raj.backend.model.Employee;
import com.raj.backend.model.EmployeeStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.time.LocalDate;
import java.util.List;

public interface ReportRepository extends JpaRepository<Employee, Long> {

    String FILTER = " WHERE e.deleted = false"
        + " AND (:from IS NULL OR e.joiningDate >= :from)"
        + " AND (:to IS NULL OR e.joiningDate <= :to)"
        + " AND (:status IS NULL OR e.status = :status)"
        + " AND (:deptId IS NULL OR e.department.id = :deptId)";

    @EntityGraph(attributePaths = "department")
    @Query("SELECT e FROM Employee e" + FILTER)
    Page<Employee> findPage(@Param("from") LocalDate from, @Param("to") LocalDate to,
                            @Param("status") EmployeeStatus status, @Param("deptId") Long deptId, Pageable pageable);

    @EntityGraph(attributePaths = "department")
    @Query("SELECT e FROM Employee e" + FILTER)
    List<Employee> findAllFiltered(@Param("from") LocalDate from, @Param("to") LocalDate to,
                                   @Param("status") EmployeeStatus status, @Param("deptId") Long deptId, Sort sort);

    @Query("SELECT COUNT(e), SUM(e.salary), AVG(e.salary) FROM Employee e" + FILTER)
    List<Object[]> totals(@Param("from") LocalDate from, @Param("to") LocalDate to,
                          @Param("status") EmployeeStatus status, @Param("deptId") Long deptId);

    @Query("SELECT e.status, COUNT(e) FROM Employee e" + FILTER + " GROUP BY e.status ORDER BY e.status")
    List<Object[]> countByStatus(@Param("from") LocalDate from, @Param("to") LocalDate to,
                                 @Param("status") EmployeeStatus status, @Param("deptId") Long deptId);

    @Query("SELECT e.department.name, COUNT(e) FROM Employee e" + FILTER + " GROUP BY e.department.name ORDER BY e.department.name")
    List<Object[]> countByDepartment(@Param("from") LocalDate from, @Param("to") LocalDate to,
                                     @Param("status") EmployeeStatus status, @Param("deptId") Long deptId);

    @Query("SELECT YEAR(e.joiningDate), MONTH(e.joiningDate), COUNT(e) FROM Employee e" + FILTER
        + " GROUP BY YEAR(e.joiningDate), MONTH(e.joiningDate) ORDER BY YEAR(e.joiningDate), MONTH(e.joiningDate)")
    List<Object[]> countByMonth(@Param("from") LocalDate from, @Param("to") LocalDate to,
                                @Param("status") EmployeeStatus status, @Param("deptId") Long deptId);
}
EOF

cat > $B/service/ReportService.java << 'EOF'
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
EOF
echo "Done A"