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
