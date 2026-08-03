package com.payflow.generator.service;

import com.payflow.generator.config.GeneratorProperties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.util.Map;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

@Service
public class SimulationScenarioService {

    private static final Logger log = LoggerFactory.getLogger(SimulationScenarioService.class);

    private final GeneratorProperties properties;
    private final SettlementGenerationService settlementGenerationService;
    private final ScheduledExecutorService scheduler = Executors.newSingleThreadScheduledExecutor();

    // Default snapshot for reset
    private final double defaultAuthSuccess;
    private final double defaultCapSuccess;
    private final int defaultTps;

    public SimulationScenarioService(GeneratorProperties properties,
                                     SettlementGenerationService settlementGenerationService) {
        this.properties = properties;
        this.settlementGenerationService = settlementGenerationService;
        this.defaultAuthSuccess = properties.getProbabilities().getAuthorizationSuccess();
        this.defaultCapSuccess = properties.getProbabilities().getCaptureSuccess();
        this.defaultTps = properties.getPayment().getTransactionsPerSecond();
    }

    public Map<String, Object> triggerFailureSpike(int durationSeconds, double failureRate) {
        double newAuthSuccess = Math.max(0.0, 1.0 - failureRate);
        properties.getProbabilities().setAuthorizationSuccess(newAuthSuccess);

        log.info("Triggered failure spike scenario: auth success lowered to {} for {} seconds", newAuthSuccess, durationSeconds);

        scheduler.schedule(() -> {
            properties.getProbabilities().setAuthorizationSuccess(defaultAuthSuccess);
            log.info("Failure spike scenario ended. Restored auth success to {}", defaultAuthSuccess);
        }, durationSeconds, TimeUnit.SECONDS);

        return Map.of(
                "scenario", "failure-spike",
                "durationSeconds", durationSeconds,
                "effectiveAuthSuccessRate", newAuthSuccess
        );
    }

    public Map<String, Object> triggerSettlementMismatch() {
        settlementGenerationService.triggerForceMismatch();
        log.info("Triggered settlement mismatch scenario for next batch");
        return Map.of(
                "scenario", "settlement-mismatch",
                "status", "ARMED_FOR_NEXT_BATCH"
        );
    }

    public Map<String, Object> triggerHighTraffic(int durationSeconds, int targetTps) {
        properties.getPayment().setTransactionsPerSecond(targetTps);
        log.info("Triggered high traffic scenario: TPS increased to {} for {} seconds", targetTps, durationSeconds);

        scheduler.schedule(() -> {
            properties.getPayment().setTransactionsPerSecond(defaultTps);
            log.info("High traffic scenario ended. Restored TPS to {}", defaultTps);
        }, durationSeconds, TimeUnit.SECONDS);

        return Map.of(
                "scenario", "high-traffic",
                "durationSeconds", durationSeconds,
                "targetTps", targetTps
        );
    }

    public Map<String, Object> resetScenarios() {
        properties.getProbabilities().setAuthorizationSuccess(defaultAuthSuccess);
        properties.getProbabilities().setCaptureSuccess(defaultCapSuccess);
        properties.getPayment().setTransactionsPerSecond(defaultTps);

        log.info("Reset all scenario overrides to default config");
        return Map.of(
                "status", "SUCCESS",
                "message", "Reset all scenario parameters to default"
        );
    }
}
