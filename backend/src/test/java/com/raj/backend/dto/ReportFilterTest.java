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
