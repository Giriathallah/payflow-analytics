package com.payflow.generator.scheduler;

import com.payflow.generator.service.RefundGenerationService;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
public class RefundScheduler {

    private final RefundGenerationService refundGenerationService;

    public RefundScheduler(RefundGenerationService refundGenerationService) {
        this.refundGenerationService = refundGenerationService;
    }

    @Scheduled(fixedRateString = "${simulation.schedules.refund-generation-ms:10000}")
    public void scheduleRefunds() {
        refundGenerationService.processRefunds();
    }
}
