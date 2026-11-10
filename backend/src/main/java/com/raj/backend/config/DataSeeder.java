package com.raj.backend.config;

import com.raj.backend.model.AppUser;
import com.raj.backend.repository.UserRepository;
import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

@Component
public class DataSeeder implements CommandLineRunner {
    private final UserRepository repo;
    private final PasswordEncoder encoder;

    public DataSeeder(UserRepository repo, PasswordEncoder encoder) {
        this.repo = repo; this.encoder = encoder;
    }

    @Override
    public void run(String... args) {
        if (repo.findByUsername("admin").isEmpty())
            repo.save(new AppUser("admin", encoder.encode("admin123"), "ADMIN"));
        if (repo.findByUsername("user").isEmpty())
            repo.save(new AppUser("user", encoder.encode("user123"), "USER"));
    }
}
