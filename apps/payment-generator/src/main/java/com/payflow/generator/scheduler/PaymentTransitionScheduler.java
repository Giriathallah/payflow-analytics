package com.payflow.generator.scheduler;

import com.payflow.generator.service.PaymentLifecycleService;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
public class PaymentTransitionScheduler {

    private final PaymentLifecycleService paymentLifecycleService;

    public PaymentTransitionScheduler(PaymentLifecycleService paymentLifecycleService) {
        this.paymentLifecycleService = paymentLifecycleService;
    }

    @Scheduled(fixedRateString = "${simulation.schedules.lifecycle-transition-ms:2000}")
    public void scheduleTransitions() {
        paymentLifecycleService.processTransitions();
    }
}
