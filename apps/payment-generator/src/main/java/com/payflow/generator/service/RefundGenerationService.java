package com.payflow.generator.service;

import com.payflow.generator.config.GeneratorProperties;
import com.payflow.generator.domain.Payment;
import com.payflow.generator.domain.PaymentStatusHistory;
import com.payflow.generator.domain.Refund;
import com.payflow.generator.repository.PaymentRepository;
import com.payflow.generator.repository.PaymentStatusHistoryRepository;
import com.payflow.generator.repository.RefundRepository;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Random;
import java.util.UUID;

@Service
public class RefundGenerationService {

    private static final Logger log = LoggerFactory.getLogger(RefundGenerationService.class);

    private final GeneratorProperties properties;
    private final PaymentRepository paymentRepository;
    private final RefundRepository refundRepository;
    private final PaymentStatusHistoryRepository paymentStatusHistoryRepository;
    private final Random random = new Random();
    private final Counter refundCounter;

    public RefundGenerationService(GeneratorProperties properties,
                                   PaymentRepository paymentRepository,
                                   RefundRepository refundRepository,
                                   PaymentStatusHistoryRepository paymentStatusHistoryRepository,
                                   MeterRegistry meterRegistry) {
        this.properties = properties;
        this.paymentRepository = paymentRepository;
        this.refundRepository = refundRepository;
        this.paymentStatusHistoryRepository = paymentStatusHistoryRepository;
        this.refundCounter = meterRegistry.counter("payflow.refunds.generated");
    }

    @Transactional
    public void processRefunds() {
        if (!properties.isEnabled()) {
            return;
        }

        double refundProb = properties.getProbabilities().getRefund();
        if (random.nextDouble() > refundProb) {
            return;
        }

        List<Payment> eligiblePayments = paymentRepository.findByStatusIn(
                List.of("CAPTURED", "SETTLED"),
                PageRequest.of(0, 10)
        );

        if (eligiblePayments.isEmpty()) {
            return;
        }

        Payment payment = eligiblePayments.get(random.nextInt(eligiblePayments.size()));

        // Determine full or partial refund amount
        boolean fullRefund = random.nextBoolean();
        BigDecimal refundAmount;
        if (fullRefund) {
            refundAmount = payment.getAmount();
        } else {
            refundAmount = payment.getAmount()
                    .multiply(BigDecimal.valueOf(0.1 + random.nextDouble() * 0.5))
                    .setScale(2, RoundingMode.HALF_UP);
        }

        boolean refundSuccess = random.nextDouble() < 0.90; // 90% success rate for refunds

        Refund refund = new Refund();
        refund.setPayment(payment);
        refund.setRefundReference("RFD-" + System.currentTimeMillis() + "-" + UUID.randomUUID().toString().substring(0, 8));
        refund.setAmount(refundAmount);
        refund.setStatus(refundSuccess ? "COMPLETED" : "FAILED");
        refund.setReason(refundSuccess ? "Customer requested refund" : "Refund rejected by issuer");
        refundRepository.save(refund);

        if (refundSuccess) {
            String oldStatus = payment.getStatus();
            int newVersion = payment.getVersion() + 1;
            payment.setVersion(newVersion);
            payment.setStatus("REFUNDED");
            paymentRepository.save(payment);

            PaymentStatusHistory history = new PaymentStatusHistory();
            history.setPayment(payment);
            history.setFromStatus(oldStatus);
            history.setToStatus("REFUNDED");
            history.setReason("Refund processed: " + refund.getRefundReference());
            history.setPaymentVersion(newVersion);
            history.setOccurredAt(OffsetDateTime.now());
            paymentStatusHistoryRepository.save(history);
        }

        refundCounter.increment();
        log.info("Generated refund {} for payment {}", refund.getRefundReference(), payment.getId());
    }
}
