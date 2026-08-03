package com.payflow.generator.controller;

import com.payflow.generator.config.GeneratorProperties;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/generator")
public class GeneratorController {

    private final GeneratorProperties properties;

    public GeneratorController(GeneratorProperties properties) {
        this.properties = properties;
    }

    @PostMapping("/start")
    public ResponseEntity<Map<String, Object>> startGenerator() {
        properties.setEnabled(true);
        return ResponseEntity.ok(Map.of("status", "STARTED", "enabled", true));
    }

    @PostMapping("/stop")
    public ResponseEntity<Map<String, Object>> stopGenerator() {
        properties.setEnabled(false);
        return ResponseEntity.ok(Map.of("status", "STOPPED", "enabled", false));
    }

    @GetMapping("/status")
    public ResponseEntity<Map<String, Object>> getStatus() {
        return ResponseEntity.ok(Map.of(
                "enabled", properties.isEnabled(),
                "transactionsPerSecond", properties.getPayment().getTransactionsPerSecond(),
                "randomSeed", properties.getRandomSeed()
        ));
    }

    @GetMapping("/config")
    public ResponseEntity<GeneratorProperties> getConfig() {
        return ResponseEntity.ok(properties);
    }

    @PutMapping("/config")
    public ResponseEntity<Map<String, Object>> updateConfig(@RequestBody Map<String, Object> updatePayload) {
        if (updatePayload.containsKey("enabled")) {
            properties.setEnabled((Boolean) updatePayload.get("enabled"));
        }
        if (updatePayload.containsKey("transactionsPerSecond")) {
            properties.getPayment().setTransactionsPerSecond(((Number) updatePayload.get("transactionsPerSecond")).intValue());
        }
        return ResponseEntity.ok(Map.of("status", "UPDATED", "config", properties));
    }
}
