package com.raj.backend.dto;

import com.raj.backend.model.EmployeeStatus;
import jakarta.validation.constraints.*;
import java.math.BigDecimal;
import java.time.LocalDate;

public record EmployeeRequest(
    @NotBlank @Size(max = 20) String empCode,
    @NotBlank @Size(min = 2, max = 100) String name,
    @NotBlank @Email @Size(max = 100) String email,
    @NotBlank @Pattern(regexp = "^[0-9]{10}$", message = "must be 10 digits") String phone,
    @NotNull Long departmentId,
    @NotBlank @Size(max = 50) String designation,
    @NotNull @Positive @Digits(integer = 10, fraction = 2) BigDecimal salary,
    @NotNull EmployeeStatus status,
    @NotNull @PastOrPresent LocalDate joiningDate
) {}
