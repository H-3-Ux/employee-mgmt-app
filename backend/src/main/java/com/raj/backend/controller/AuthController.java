package com.raj.backend.controller;

import com.raj.backend.repository.UserRepository;
import com.raj.backend.security.JwtUtil;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import org.springframework.http.ResponseEntity;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;
import java.util.Map;

@RestController
@RequestMapping("/api/auth")
public class AuthController {
    private final UserRepository repo;
    private final PasswordEncoder encoder;
    private final JwtUtil jwtUtil;

    public AuthController(UserRepository repo, PasswordEncoder encoder, JwtUtil jwtUtil) {
        this.repo = repo; this.encoder = encoder; this.jwtUtil = jwtUtil;
    }

    public record LoginRequest(@NotBlank @Size(min = 3) String username,
                               @NotBlank @Size(min = 6) String password) {}
    public record LoginResponse(String token, String username, String role) {}

    @PostMapping("/login")
    public ResponseEntity<?> login(@Valid @RequestBody LoginRequest req) {
        return repo.findByUsername(req.username())
            .filter(u -> encoder.matches(req.password(), u.getPassword()))
            .<ResponseEntity<?>>map(u -> ResponseEntity.ok(
                new LoginResponse(jwtUtil.generate(u.getUsername(), u.getRole()), u.getUsername(), u.getRole())))
            .orElse(ResponseEntity.status(401).body(Map.of("message", "Invalid username or password")));
    }
}
