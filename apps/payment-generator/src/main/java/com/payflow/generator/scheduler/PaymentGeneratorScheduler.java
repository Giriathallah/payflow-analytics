package com.payflow.generator.scheduler;

import com.payflow.generator.service.PaymentGenerationService;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
public class PaymentGeneratorScheduler {

    private final PaymentGenerationService paymentGenerationService;

    public PaymentGeneratorScheduler(PaymentGenerationService paymentGenerationService) {
        this.paymentGenerationService = paymentGenerationService;
    }

    @Scheduled(fixedRateString = "${simulation.schedules.payment-generation-ms:1000}")
    public void schedulePaymentGeneration() {
        paymentGenerationService.generatePaymentsBatch();
    }
}
