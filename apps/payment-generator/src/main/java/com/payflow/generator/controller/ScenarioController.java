package com.payflow.generator.controller;

import com.payflow.generator.service.SimulationScenarioService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/scenarios")
public class ScenarioController {

    private final SimulationScenarioService scenarioService;

    public ScenarioController(SimulationScenarioService scenarioService) {
        this.scenarioService = scenarioService;
    }

    @PostMapping("/failure-spike")
    public ResponseEntity<Map<String, Object>> failureSpike(
            @RequestParam(defaultValue = "60") int durationSeconds,
            @RequestParam(defaultValue = "0.4") double failureRate) {
        Map<String, Object> response = scenarioService.triggerFailureSpike(durationSeconds, failureRate);
        return ResponseEntity.ok(response);
    }

    @PostMapping("/settlement-mismatch")
    public ResponseEntity<Map<String, Object>> settlementMismatch() {
        Map<String, Object> response = scenarioService.triggerSettlementMismatch();
        return ResponseEntity.ok(response);
    }

    @PostMapping("/high-traffic")
    public ResponseEntity<Map<String, Object>> highTraffic(
            @RequestParam(defaultValue = "60") int durationSeconds,
            @RequestParam(defaultValue = "20") int targetTps) {
        Map<String, Object> response = scenarioService.triggerHighTraffic(durationSeconds, targetTps);
        return ResponseEntity.ok(response);
    }

    @PostMapping("/reset")
    public ResponseEntity<Map<String, Object>> resetScenarios() {
        Map<String, Object> response = scenarioService.resetScenarios();
        return ResponseEntity.ok(response);
    }
}
