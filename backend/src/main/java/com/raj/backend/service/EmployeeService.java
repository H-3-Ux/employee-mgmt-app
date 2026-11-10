package com.raj.backend.service;

import com.raj.backend.dto.EmployeeRequest;
import com.raj.backend.dto.EmployeeResponse;
import com.raj.backend.dto.PageResponse;
import com.raj.backend.exception.DuplicateException;
import com.raj.backend.exception.NotFoundException;
import com.raj.backend.model.Department;
import com.raj.backend.model.Employee;
import com.raj.backend.repository.DepartmentRepository;
import com.raj.backend.repository.EmployeeRepository;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional
public class EmployeeService {
    private final EmployeeRepository repo;
    private final DepartmentRepository deptRepo;

    public EmployeeService(EmployeeRepository repo, DepartmentRepository deptRepo) {
        this.repo = repo; this.deptRepo = deptRepo;
    }

    @Transactional(readOnly = true)
    public PageResponse<EmployeeResponse> list(String q, Pageable pageable) {
        return PageResponse.of(repo.search(q == null ? "" : q.trim(), pageable).map(EmployeeResponse::from));
    }

    @Transactional(readOnly = true)
    public EmployeeResponse get(Long id) {
        return EmployeeResponse.from(find(id));
    }

    public EmployeeResponse create(EmployeeRequest r) {
        if (repo.existsByEmpCodeIgnoreCase(r.empCode().trim())) throw new DuplicateException("Employee code already exists");
        if (repo.existsByEmailIgnoreCase(r.email().trim())) throw new DuplicateException("Email already exists");
        Employee e = new Employee();
        apply(e, r);
        return EmployeeResponse.from(repo.save(e));
    }

    public EmployeeResponse update(Long id, EmployeeRequest r) {
        Employee e = find(id);
        if (repo.existsByEmpCodeIgnoreCaseAndIdNot(r.empCode().trim(), id)) throw new DuplicateException("Employee code already exists");
        if (repo.existsByEmailIgnoreCaseAndIdNot(r.email().trim(), id)) throw new DuplicateException("Email already exists");
        apply(e, r);
        return EmployeeResponse.from(repo.save(e));
    }

    public void delete(Long id) {
        find(id).setDeleted(true); // soft delete
    }

    private Employee find(Long id) {
        return repo.findByIdAndDeletedFalse(id).orElseThrow(() -> new NotFoundException("Employee not found: " + id));
    }

    private void apply(Employee e, EmployeeRequest r) {
        Department d = deptRepo.findById(r.departmentId())
            .orElseThrow(() -> new NotFoundException("Department not found: " + r.departmentId()));
        e.setEmpCode(r.empCode().trim().toUpperCase());
        e.setName(r.name().trim());
        e.setEmail(r.email().trim().toLowerCase());
        e.setPhone(r.phone().trim());
        e.setDepartment(d);
        e.setDesignation(r.designation().trim());
        e.setSalary(r.salary());
        e.setStatus(r.status());
        e.setJoiningDate(r.joiningDate());
    }
}
