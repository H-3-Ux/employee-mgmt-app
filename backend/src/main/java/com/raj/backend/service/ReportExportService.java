package com.raj.backend.service;

import com.lowagie.text.Document;
import com.lowagie.text.Element;
import com.lowagie.text.HeaderFooter;
import com.lowagie.text.PageSize;
import com.lowagie.text.Paragraph;
import com.lowagie.text.Phrase;
import com.lowagie.text.Rectangle;
import com.lowagie.text.pdf.PdfPCell;
import com.lowagie.text.pdf.PdfPTable;
import com.lowagie.text.pdf.PdfWriter;
import com.raj.backend.dto.ReportFilter;
import com.raj.backend.model.Employee;
import org.apache.poi.ss.usermodel.Cell;
import org.apache.poi.ss.usermodel.CellStyle;
import org.apache.poi.ss.usermodel.FillPatternType;
import org.apache.poi.ss.usermodel.IndexedColors;
import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.ss.usermodel.Workbook;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.awt.Color;
import java.io.ByteArrayOutputStream;
import java.time.LocalDate;
import java.util.List;

@Service
@Transactional(readOnly = true)
public class ReportExportService {
    private static final String[] HEADERS =
        {"Emp Code", "Name", "Email", "Phone", "Department", "Designation", "Salary", "Status", "Joining Date"};
    private final ReportService reportService;

    public ReportExportService(ReportService reportService) { this.reportService = reportService; }

    private String[] values(Employee e) {
        return new String[]{e.getEmpCode(), e.getName(), e.getEmail(), e.getPhone(), e.getDepartment().getName(),
            e.getDesignation(), e.getSalary().toPlainString(), e.getStatus().name(), e.getJoiningDate().toString()};
    }

    public byte[] excel(ReportFilter f) {
        List<Employee> rows = reportService.allForExport(f);
        try (Workbook wb = new XSSFWorkbook(); ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            Sheet sh = wb.createSheet("Employees");
            CellStyle head = wb.createCellStyle();
            org.apache.poi.ss.usermodel.Font bold = wb.createFont();
            bold.setBold(true);
            head.setFont(bold);
            head.setFillForegroundColor(IndexedColors.GREY_25_PERCENT.getIndex());
            head.setFillPattern(FillPatternType.SOLID_FOREGROUND);
            CellStyle date = wb.createCellStyle();
            date.setDataFormat(wb.getCreationHelper().createDataFormat().getFormat("yyyy-mm-dd"));
            CellStyle money = wb.createCellStyle();
            money.setDataFormat(wb.getCreationHelper().createDataFormat().getFormat("#,##0.00"));

            Row hr = sh.createRow(0);
            for (int i = 0; i < HEADERS.length; i++) {
                Cell c = hr.createCell(i);
                c.setCellValue(HEADERS[i]);
                c.setCellStyle(head);
                sh.setColumnWidth(i, (i == 2 ? 32 : 18) * 256);
            }
            int r = 1;
            for (Employee e : rows) {
                Row row = sh.createRow(r++);
                String[] v = values(e);
                for (int i = 0; i < v.length; i++) {
                    Cell c = row.createCell(i);
                    if (i == 6) { c.setCellValue(e.getSalary().doubleValue()); c.setCellStyle(money); }
                    else if (i == 8) { c.setCellValue(e.getJoiningDate()); c.setCellStyle(date); }
                    else c.setCellValue(v[i]);
                }
            }
            sh.createFreezePane(0, 1);
            wb.write(out);
            return out.toByteArray();
        } catch (Exception ex) {
            throw new IllegalStateException("Excel export failed", ex);
        }
    }

    public byte[] pdf(ReportFilter f) {
        List<Employee> rows = reportService.allForExport(f);
        try (ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            Document doc = new Document(PageSize.A4.rotate(), 30, 30, 30, 40);
            PdfWriter.getInstance(doc, out);
            HeaderFooter footer = new HeaderFooter(new Phrase("Employee Management System  |  Page "), true);
            footer.setAlignment(Element.ALIGN_CENTER);
            footer.setBorder(Rectangle.TOP);
            doc.setFooter(footer);
            doc.open();

            com.lowagie.text.Font title = new com.lowagie.text.Font(com.lowagie.text.Font.HELVETICA, 16, com.lowagie.text.Font.BOLD);
            com.lowagie.text.Font small = new com.lowagie.text.Font(com.lowagie.text.Font.HELVETICA, 9);
            com.lowagie.text.Font th = new com.lowagie.text.Font(com.lowagie.text.Font.HELVETICA, 9, com.lowagie.text.Font.BOLD);

            doc.add(new Paragraph("Employee Report", title));
            doc.add(new Paragraph("Generated on: " + LocalDate.now() + "    Period: " + f.periodLabel()
                + "    Total records: " + rows.size(), small));
            doc.add(new Paragraph(" "));

            PdfPTable table = new PdfPTable(HEADERS.length);
            table.setWidthPercentage(100);
            table.setWidths(new float[]{1.1f, 1.8f, 2.6f, 1.3f, 1.3f, 1.5f, 1.1f, 1.1f, 1.2f});
            table.setHeaderRows(1);
            for (String h : HEADERS) {
                PdfPCell c = new PdfPCell(new Phrase(h, th));
                c.setBackgroundColor(new Color(225, 225, 225));
                c.setPadding(5);
                table.addCell(c);
            }
            for (Employee e : rows)
                for (String v : values(e)) {
                    PdfPCell c = new PdfPCell(new Phrase(v, small));
                    c.setPadding(4);
                    table.addCell(c);
                }
            doc.add(table);
            doc.close();
            return out.toByteArray();
        } catch (Exception ex) {
            throw new IllegalStateException("PDF export failed", ex);
        }
    }
}
