package com.raj.backend.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.ExpiredJwtException;
import io.jsonwebtoken.JwtException;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class JwtUtilTest {
    private static final String SECRET = "test-secret-key-that-is-at-least-32-characters-long";

    @Test
    void generateAndParse_returnsSubjectAndRole() {
        JwtUtil jwt = new JwtUtil(SECRET, 30);
        Claims c = jwt.parse(jwt.generate("admin", "ADMIN"));
        assertEquals("admin", c.getSubject());
        assertEquals("ADMIN", c.get("role", String.class));
    }

    @Test
    void parse_rejectsTamperedToken() {
        JwtUtil jwt = new JwtUtil(SECRET, 30);
        String token = jwt.generate("admin", "ADMIN");
        String tampered = token.substring(0, token.length() - 2) + (token.endsWith("AA") ? "BB" : "AA");
        assertThrows(JwtException.class, () -> jwt.parse(tampered));
    }

    @Test
    void parse_rejectsTokenSignedWithDifferentKey() {
        String token = new JwtUtil("another-secret-key-that-is-also-32-chars-long!!", 30).generate("admin", "ADMIN");
        assertThrows(JwtException.class, () -> new JwtUtil(SECRET, 30).parse(token));
    }

    @Test
    void parse_rejectsExpiredToken() {
        JwtUtil jwt = new JwtUtil(SECRET, -1); // already expired
        String token = jwt.generate("admin", "ADMIN");
        assertThrows(ExpiredJwtException.class, () -> jwt.parse(token));
    }
}
