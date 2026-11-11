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
