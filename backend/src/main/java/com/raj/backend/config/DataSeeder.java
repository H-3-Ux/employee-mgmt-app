package com.raj.backend.config;

import com.raj.backend.model.*;
import com.raj.backend.repository.*;
import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

@Component
public class DataSeeder implements CommandLineRunner {
    private final UserRepository userRepo;
    private final DepartmentRepository deptRepo;
    private final EmployeeRepository empRepo;
    private final PasswordEncoder encoder;

    public DataSeeder(UserRepository userRepo, DepartmentRepository deptRepo,
                      EmployeeRepository empRepo, PasswordEncoder encoder) {
        this.userRepo = userRepo; this.deptRepo = deptRepo; this.empRepo = empRepo; this.encoder = encoder;
    }

    @Override
    public void run(String... args) {
        if (userRepo.findByUsername("admin").isEmpty())
            userRepo.save(new AppUser("admin", encoder.encode("admin123"), "ADMIN"));
        if (userRepo.findByUsername("user").isEmpty())
            userRepo.save(new AppUser("user", encoder.encode("user123"), "USER"));

        if (deptRepo.count() == 0)
            deptRepo.saveAll(List.of(new Department("Engineering"), new Department("HR"),
                new Department("Finance"), new Department("Sales"), new Department("Operations")));

        if (empRepo.count() == 0) {
            List<Department> depts = deptRepo.findAll();
            String[] names = {"Aarav Sharma", "Priya Reddy", "Rahul Verma", "Sneha Iyer", "Vikram Rao",
                "Ananya Gupta", "Karthik Nair", "Divya Menon", "Arjun Patel", "Meera Joshi",
                "Rohan Das", "Kavya Pillai", "Siddharth Jain", "Pooja Kulkarni", "Nikhil Chowdary",
                "Lakshmi Prasad", "Aditya Singh", "Swathi Naidu", "Manoj Kumar", "Harini Krishnan",
                "Varun Mehta", "Deepika Rao", "Suresh Babu", "Nandini Varma", "Ravi Teja"};
            String[] roles = {"Developer", "Senior Developer", "Analyst", "Manager", "Associate"};
            for (int i = 0; i < names.length; i++) {
                Employee e = new Employee();
                e.setEmpCode(String.format("EMP%03d", i + 1));
                e.setName(names[i]);
                e.setEmail(names[i].toLowerCase().replace(" ", ".") + "@company.com");
                e.setPhone(String.format("98765%05d", i + 1));
                e.setDepartment(depts.get(i % depts.size()));
                e.setDesignation(roles[i % roles.length]);
                e.setSalary(BigDecimal.valueOf(30000 + (i * 3500L) % 90000));
                e.setStatus(i % 5 == 3 ? EmployeeStatus.INACTIVE : i % 7 == 4 ? EmployeeStatus.ON_LEAVE : EmployeeStatus.ACTIVE);
                e.setJoiningDate(LocalDate.now().minusDays(i * 9L));
                empRepo.save(e);
            }
        }
    }
}
