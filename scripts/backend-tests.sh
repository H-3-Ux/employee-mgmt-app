#!/bin/bash
set -e
# ---------- frontend polish ----------
F=/workspaces/employee-mgmt-app/frontend/src/app/pages/reports/report.component.ts
sed -i "s|@else { <mat-hint>DD/MM/YYYY – DD/MM/YYYY</mat-hint> }||" $F
sed -i 's|<mat-form-field appearance="outline">\n      <mat-label>Department|&|' $F
python3 - << 'PYEOF'
p='/workspaces/employee-mgmt-app/frontend/src/app/pages/reports/report.component.ts'; s=open(p).read()
s=s.replace('<mat-form-field appearance="outline">\n      <mat-label>Status</mat-label>','<mat-form-field appearance="outline" floatLabel="always">\n      <mat-label>Status</mat-label>')
s=s.replace('<mat-form-field appearance="outline">\n      <mat-label>Department</mat-label>','<mat-form-field appearance="outline" floatLabel="always">\n      <mat-label>Department</mat-label>')
open(p,'w').write(s)
PYEOF

# ---------- backend tests ----------
cd /workspaces/employee-mgmt-app/backend
T=src/test/java/com/raj/backend
rm -f $T/BackendApplicationTests.java   # needs a live DB; replaced by unit tests below
mkdir -p $T/service $T/security $T/dto

cat > $T/service/EmployeeServiceTest.java << 'EOF'
package com.raj.backend.service;

import com.raj.backend.dto.EmployeeRequest;
import com.raj.backend.dto.EmployeeResponse;
import com.raj.backend.exception.DuplicateException;
import com.raj.backend.exception.NotFoundException;
import com.raj.backend.model.Department;
import com.raj.backend.model.Employee;
import com.raj.backend.model.EmployeeStatus;
import com.raj.backend.repository.DepartmentRepository;
import com.raj.backend.repository.EmployeeRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class EmployeeServiceTest {

    @Mock EmployeeRepository repo;
    @Mock DepartmentRepository deptRepo;
    @InjectMocks EmployeeService service;

    private EmployeeRequest request() {
        return new EmployeeRequest(" emp100 ", "John Doe", "John@Company.com", "9876543210", 1L,
            "Developer", new BigDecimal("50000"), EmployeeStatus.ACTIVE, LocalDate.now());
    }

    @Test
    void create_savesEmployee_withNormalizedCodeAndEmail() {
        when(repo.existsByEmpCodeIgnoreCase("emp100")).thenReturn(false);
        when(repo.existsByEmailIgnoreCase("John@Company.com")).thenReturn(false);
        when(deptRepo.findById(1L)).thenReturn(Optional.of(new Department("Engineering")));
        when(repo.save(any(Employee.class))).thenAnswer(inv -> inv.getArgument(0));

        EmployeeResponse res = service.create(request());

        assertEquals("EMP100", res.empCode());
        assertEquals("john@company.com", res.email());
        assertEquals("Engineering", res.departmentName());
        verify(repo).save(any(Employee.class));
    }

    @Test
    void create_throwsDuplicate_whenEmailExists() {
        when(repo.existsByEmpCodeIgnoreCase(anyString())).thenReturn(false);
        when(repo.existsByEmailIgnoreCase(anyString())).thenReturn(true);

        DuplicateException ex = assertThrows(DuplicateException.class, () -> service.create(request()));
        assertEquals("Email already exists", ex.getMessage());
        verify(repo, never()).save(any());
    }

    @Test
    void create_throwsDuplicate_whenCodeExists() {
        when(repo.existsByEmpCodeIgnoreCase(anyString())).thenReturn(true);

        assertThrows(DuplicateException.class, () -> service.create(request()));
        verify(repo, never()).save(any());
    }

    @Test
    void create_throwsNotFound_whenDepartmentMissing() {
        when(repo.existsByEmpCodeIgnoreCase(anyString())).thenReturn(false);
        when(repo.existsByEmailIgnoreCase(anyString())).thenReturn(false);
        when(deptRepo.findById(1L)).thenReturn(Optional.empty());

        assertThrows(NotFoundException.class, () -> service.create(request()));
        verify(repo, never()).save(any());
    }

    @Test
    void update_throwsNotFound_whenEmployeeMissing() {
        when(repo.findByIdAndDeletedFalse(99L)).thenReturn(Optional.empty());

        assertThrows(NotFoundException.class, () -> service.update(99L, request()));
    }

    @Test
    void delete_isSoftDelete() {
        Employee e = new Employee();
        when(repo.findByIdAndDeletedFalse(5L)).thenReturn(Optional.of(e));

        service.delete(5L);

        assertTrue(e.isDeleted());
        verify(repo, never()).delete(any());
        verify(repo, never()).deleteById(any());
    }
}
EOF

cat > $T/security/JwtUtilTest.java << 'EOF'
package com.raj.backend.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.ExpiredJwtException;
import io.jsonwebtoken.JwtException;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class JwtUtilTest {
    private static final String SECRET = "test-secret-key-that-is-at-least-32-characters-long";

    @Test
    void generateAndParse_returnsSubjectAndRole() {
        JwtUtil jwt = new JwtUtil(SECRET, 30);
        Claims c = jwt.parse(jwt.generate("admin", "ADMIN"));
        assertEquals("admin", c.getSubject());
        assertEquals("ADMIN", c.get("role", String.class));
    }

    @Test
    void parse_rejectsTamperedToken() {
        JwtUtil jwt = new JwtUtil(SECRET, 30);
        String token = jwt.generate("admin", "ADMIN");
        String tampered = token.substring(0, token.length() - 2) + (token.endsWith("AA") ? "BB" : "AA");
        assertThrows(JwtException.class, () -> jwt.parse(tampered));
    }

    @Test
    void parse_rejectsTokenSignedWithDifferentKey() {
        String token = new JwtUtil("another-secret-key-that-is-also-32-chars-long!!", 30).generate("admin", "ADMIN");
        assertThrows(JwtException.class, () -> new JwtUtil(SECRET, 30).parse(token));
    }

    @Test
    void parse_rejectsExpiredToken() {
        JwtUtil jwt = new JwtUtil(SECRET, -1); // already expired
        String token = jwt.generate("admin", "ADMIN");
        assertThrows(ExpiredJwtException.class, () -> jwt.parse(token));
    }
}
EOF

cat > $T/dto/ReportFilterTest.java << 'EOF'
package com.raj.backend.dto;

import org.junit.jupiter.api.Test;
import java.time.LocalDate;

import static org.junit.jupiter.api.Assertions.*;

class ReportFilterTest {

    @Test
    void validate_throws_whenFromAfterTo() {
        ReportFilter f = new ReportFilter();
        f.setFrom(LocalDate.of(2026, 12, 1));
        f.setTo(LocalDate.of(2026, 1, 1));
        assertThrows(IllegalArgumentException.class, f::validate);
    }

    @Test
    void validate_passes_forValidOrOpenRange() {
        ReportFilter f = new ReportFilter();
        f.setFrom(LocalDate.of(2026, 1, 1));
        f.setTo(LocalDate.of(2026, 1, 1));
        assertDoesNotThrow(f::validate);

        ReportFilter open = new ReportFilter();
        assertDoesNotThrow(open::validate);
    }
}
EOF
echo "Done tests. Running..."
./mvnw -q test
echo "ALL TESTS PASSED"