package com.payflow.generator.service;

import com.payflow.generator.config.GeneratorProperties;
import com.payflow.generator.domain.Payment;
import com.payflow.generator.domain.PaymentStatusHistory;
import com.payflow.generator.repository.PaymentRepository;
import com.payflow.generator.repository.PaymentStatusHistoryRepository;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Random;

@Service
public class PaymentLifecycleService {

    private static final Logger log = LoggerFactory.getLogger(PaymentLifecycleService.class);

    private final GeneratorProperties properties;
    private final PaymentRepository paymentRepository;
    private final PaymentStatusHistoryRepository paymentStatusHistoryRepository;
    private final Random random = new Random();
    private final Counter transitionsCounter;

    public PaymentLifecycleService(GeneratorProperties properties,
                                   PaymentRepository paymentRepository,
                                   PaymentStatusHistoryRepository paymentStatusHistoryRepository,
                                   MeterRegistry meterRegistry) {
        this.properties = properties;
        this.paymentRepository = paymentRepository;
        this.paymentStatusHistoryRepository = paymentStatusHistoryRepository;
        this.transitionsCounter = meterRegistry.counter("payflow.payments.transitions");
    }

    @Transactional
    public void processTransitions() {
        if (!properties.isEnabled()) {
            return;
        }

        // Process INITIATED payments -> AUTHORIZED or FAILED
        List<Payment> initiatedPayments = paymentRepository.findByStatus("INITIATED", PageRequest.of(0, 50));
        for (Payment payment : initiatedPayments) {
            double authProb = properties.getProbabilities().getAuthorizationSuccess();
            boolean success = random.nextDouble() < authProb;

            String oldStatus = payment.getStatus();
            int newVersion = payment.getVersion() + 1;
            payment.setVersion(newVersion);
            OffsetDateTime now = OffsetDateTime.now();

            if (success) {
                payment.setStatus("AUTHORIZED");
                payment.setAuthorizedAt(now);
                recordHistory(payment, oldStatus, "AUTHORIZED", "Authorization successful", newVersion, now);
            } else {
                payment.setStatus("FAILED");
                payment.setFailureReason("Bank network timeout / insufficient funds");
                recordHistory(payment, oldStatus, "FAILED", payment.getFailureReason(), newVersion, now);
            }

            paymentRepository.save(payment);
            transitionsCounter.increment();
        }

        // Process AUTHORIZED payments -> CAPTURED, FAILED, or EXPIRED
        List<Payment> authorizedPayments = paymentRepository.findByStatus("AUTHORIZED", PageRequest.of(0, 50));
        for (Payment payment : authorizedPayments) {
            double capProb = properties.getProbabilities().getCaptureSuccess();
            double roll = random.nextDouble();

            String oldStatus = payment.getStatus();
            int newVersion = payment.getVersion() + 1;
            payment.setVersion(newVersion);
            OffsetDateTime now = OffsetDateTime.now();

            if (roll < capProb) {
                payment.setStatus("CAPTURED");
                payment.setCapturedAt(now);
                recordHistory(payment, oldStatus, "CAPTURED", "Payment captured successfully", newVersion, now);
            } else if (roll < capProb + 0.03) {
                payment.setStatus("FAILED");
                payment.setFailureReason("Capture rejected by provider");
                recordHistory(payment, oldStatus, "FAILED", payment.getFailureReason(), newVersion, now);
            } else {
                payment.setStatus("EXPIRED");
                payment.setFailureReason("Payment authorization expired");
                recordHistory(payment, oldStatus, "EXPIRED", payment.getFailureReason(), newVersion, now);
            }

            paymentRepository.save(payment);
            transitionsCounter.increment();
        }
    }

    private void recordHistory(Payment payment, String fromStatus, String toStatus, String reason, int version, OffsetDateTime occurredAt) {
        PaymentStatusHistory history = new PaymentStatusHistory();
        history.setPayment(payment);
        history.setFromStatus(fromStatus);
        history.setToStatus(toStatus);
        history.setReason(reason);
        history.setPaymentVersion(version);
        history.setOccurredAt(occurredAt);
        paymentStatusHistoryRepository.save(history);
    }
}
