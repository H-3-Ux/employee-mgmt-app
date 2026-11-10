package com.raj.backend.controller;

import com.raj.backend.model.Department;
import com.raj.backend.repository.DepartmentRepository;
import org.springframework.data.domain.Sort;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
@RequestMapping("/api/departments")
public class DepartmentController {
    private final DepartmentRepository repo;

    public DepartmentController(DepartmentRepository repo) { this.repo = repo; }

    @GetMapping
    public List<Department> list() { return repo.findAll(Sort.by("name")); }
}
