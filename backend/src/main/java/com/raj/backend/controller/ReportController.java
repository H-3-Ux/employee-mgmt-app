package com.raj.backend.controller;

import com.raj.backend.dto.EmployeeResponse;
import com.raj.backend.dto.PageResponse;
import com.raj.backend.dto.ReportFilter;
import com.raj.backend.dto.ReportSummary;
import com.raj.backend.service.ReportExportService;
import com.raj.backend.service.ReportService;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.time.LocalDate;

@RestController
@RequestMapping("/api/reports")
public class ReportController {
    private final ReportService reportService;
    private final ReportExportService exportService;

    public ReportController(ReportService reportService, ReportExportService exportService) {
        this.reportService = reportService; this.exportService = exportService;
    }

    @GetMapping("/employees")
    public PageResponse<EmployeeResponse> list(@ModelAttribute ReportFilter filter,
            @PageableDefault(size = 10, sort = "joiningDate", direction = Sort.Direction.DESC) Pageable pageable) {
        return reportService.list(filter, pageable);
    }

    @GetMapping("/summary")
    public ReportSummary summary(@ModelAttribute ReportFilter filter) {
        return reportService.summary(filter);
    }

    @GetMapping("/export/excel")
    public ResponseEntity<byte[]> excel(@ModelAttribute ReportFilter filter) {
        return file(exportService.excel(filter), "xlsx",
            MediaType.parseMediaType("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"));
    }

    @GetMapping("/export/pdf")
    public ResponseEntity<byte[]> pdf(@ModelAttribute ReportFilter filter) {
        return file(exportService.pdf(filter), "pdf", MediaType.APPLICATION_PDF);
    }

    private ResponseEntity<byte[]> file(byte[] body, String ext, MediaType type) {
        return ResponseEntity.ok()
            .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"employee-report-" + LocalDate.now() + "." + ext + "\"")
            .header(HttpHeaders.ACCESS_CONTROL_EXPOSE_HEADERS, HttpHeaders.CONTENT_DISPOSITION)
            .contentType(type)
            .body(body);
    }
}
