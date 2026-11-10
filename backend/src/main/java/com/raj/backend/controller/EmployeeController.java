package com.raj.backend.controller;

import com.raj.backend.dto.EmployeeRequest;
import com.raj.backend.dto.EmployeeResponse;
import com.raj.backend.dto.PageResponse;
import com.raj.backend.service.EmployeeService;
import jakarta.validation.Valid;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/employees")
public class EmployeeController {
    private final EmployeeService service;

    public EmployeeController(EmployeeService service) { this.service = service; }

    @GetMapping
    public PageResponse<EmployeeResponse> list(@RequestParam(defaultValue = "") String q,
                                               @PageableDefault(size = 10, sort = "id") Pageable pageable) {
        return service.list(q, pageable);
    }

    @GetMapping("/{id}")
    public EmployeeResponse get(@PathVariable Long id) { return service.get(id); }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public EmployeeResponse create(@Valid @RequestBody EmployeeRequest req) { return service.create(req); }

    @PutMapping("/{id}")
    public EmployeeResponse update(@PathVariable Long id, @Valid @RequestBody EmployeeRequest req) {
        return service.update(id, req);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) { service.delete(id); }
}
