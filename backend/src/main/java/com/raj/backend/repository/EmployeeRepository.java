package com.raj.backend.repository;

import com.raj.backend.model.Employee;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.Optional;

public interface EmployeeRepository extends JpaRepository<Employee, Long> {

    @EntityGraph(attributePaths = "department")
    @Query("""
        SELECT e FROM Employee e
        WHERE e.deleted = false
          AND (:q = ''
               OR LOWER(e.name) LIKE LOWER(CONCAT('%', :q, '%'))
               OR LOWER(e.email) LIKE LOWER(CONCAT('%', :q, '%'))
               OR LOWER(e.empCode) LIKE LOWER(CONCAT('%', :q, '%')))
        """)
    Page<Employee> search(@Param("q") String q, Pageable pageable);

    @EntityGraph(attributePaths = "department")
    Optional<Employee> findByIdAndDeletedFalse(Long id);

    boolean existsByEmpCodeIgnoreCase(String empCode);
    boolean existsByEmailIgnoreCase(String email);
    boolean existsByEmpCodeIgnoreCaseAndIdNot(String empCode, Long id);
    boolean existsByEmailIgnoreCaseAndIdNot(String email, Long id);
}
