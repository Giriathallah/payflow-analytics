package com.payflow.generator.scheduler;

import com.payflow.generator.service.SettlementGenerationService;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
public class SettlementScheduler {

    private final SettlementGenerationService settlementGenerationService;

    public SettlementScheduler(SettlementGenerationService settlementGenerationService) {
        this.settlementGenerationService = settlementGenerationService;
    }

    @Scheduled(fixedRateString = "${simulation.schedules.settlement-generation-ms:60000}")
    public void scheduleSettlement() {
        settlementGenerationService.processSettlement();
    }
}
