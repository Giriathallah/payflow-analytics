package com.payflow.generator.service;

import com.payflow.generator.config.GeneratorProperties;
import com.payflow.generator.domain.*;
import com.payflow.generator.repository.*;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Random;
import java.util.UUID;

@Service
public class SettlementGenerationService {

    private static final Logger log = LoggerFactory.getLogger(SettlementGenerationService.class);

    private final GeneratorProperties properties;
    private final MerchantRepository merchantRepository;
    private final PaymentRepository paymentRepository;
    private final SettlementBatchRepository settlementBatchRepository;
    private final SettlementItemRepository settlementItemRepository;
    private final PaymentStatusHistoryRepository paymentStatusHistoryRepository;
    private final Random random = new Random();
    private final Counter settlementCounter;

    private boolean forceMismatchNextBatch = false;

    public SettlementGenerationService(GeneratorProperties properties,
                                       MerchantRepository merchantRepository,
                                       PaymentRepository paymentRepository,
                                       SettlementBatchRepository settlementBatchRepository,
                                       SettlementItemRepository settlementItemRepository,
                                       PaymentStatusHistoryRepository paymentStatusHistoryRepository,
                                       MeterRegistry meterRegistry) {
        this.properties = properties;
        this.merchantRepository = merchantRepository;
        this.paymentRepository = paymentRepository;
        this.settlementBatchRepository = settlementBatchRepository;
        this.settlementItemRepository = settlementItemRepository;
        this.paymentStatusHistoryRepository = paymentStatusHistoryRepository;
        this.settlementCounter = meterRegistry.counter("payflow.settlements.generated");
    }

    public void triggerForceMismatch() {
        this.forceMismatchNextBatch = true;
    }

    @Transactional
    public void processSettlement() {
        if (!properties.isEnabled()) {
            return;
        }

        List<Merchant> merchants = merchantRepository.findByIsActiveTrue();
        for (Merchant merchant : merchants) {
            List<Payment> capturedPayments = paymentRepository.findCapturedPaymentsByMerchant(
                    merchant.getId(), PageRequest.of(0, 100)
            );

            if (capturedPayments.isEmpty()) {
                continue;
            }

            BigDecimal grossAmount = BigDecimal.ZERO;
            BigDecimal feeAmount = BigDecimal.ZERO;

            for (Payment payment : capturedPayments) {
                grossAmount = grossAmount.add(payment.getAmount());
                feeAmount = feeAmount.add(payment.getFeeAmount());
            }

            BigDecimal refundAmount = BigDecimal.ZERO; // captured payments don't have refunds yet
            BigDecimal expectedNet = grossAmount.subtract(feeAmount).subtract(refundAmount);

            boolean shouldMismatch = forceMismatchNextBatch ||
                    (random.nextDouble() < properties.getProbabilities().getSettlementMismatch());
            if (forceMismatchNextBatch) {
                forceMismatchNextBatch = false; // consume trigger
            }

            BigDecimal actualNet;
            String batchStatus;

            if (shouldMismatch) {
                // Introduce a mismatch discrepancy of e.g. -10,000 or -50,000 IDR
                BigDecimal discrepancy = BigDecimal.valueOf(10000 + random.nextInt(40000));
                actualNet = expectedNet.subtract(discrepancy);
                batchStatus = "MISMATCH";
                log.warn("Simulated settlement mismatch for merchant {}: expected {}, actual {}",
                        merchant.getName(), expectedNet, actualNet);
            } else {
                actualNet = expectedNet;
                batchStatus = "COMPLETED";
            }

            SettlementBatch batch = new SettlementBatch();
            batch.setMerchant(merchant);
            batch.setSettlementReference("SETTL-" + System.currentTimeMillis() + "-" + UUID.randomUUID().toString().substring(0, 8));
            batch.setSettlementDate(LocalDate.now());
            batch.setGrossAmount(grossAmount);
            batch.setFeeAmount(feeAmount);
            batch.setRefundAmount(refundAmount);
            batch.setExpectedNetAmount(expectedNet);
            batch.setActualNetAmount(actualNet);
            batch.setStatus(batchStatus);

            SettlementBatch savedBatch = settlementBatchRepository.save(batch);

            for (Payment payment : capturedPayments) {
                BigDecimal expItemAmt = payment.getAmount().subtract(payment.getFeeAmount());
                BigDecimal actItemAmt = expItemAmt;
                String itemReconciliation = "MATCHED";

                if (shouldMismatch && random.nextDouble() < 0.3) {
                    // Mark specific item as mismatched
                    actItemAmt = expItemAmt.subtract(BigDecimal.valueOf(5000));
                    itemReconciliation = "AMOUNT_MISMATCH";
                }

                SettlementItem item = new SettlementItem();
                item.setSettlementBatch(savedBatch);
                item.setPayment(payment);
                item.setExpectedAmount(expItemAmt);
                item.setActualAmount(actItemAmt);
                item.setReconciliationStatus(itemReconciliation);
                settlementItemRepository.save(item);

                // Update Payment status to SETTLED
                String oldStatus = payment.getStatus();
                int newVersion = payment.getVersion() + 1;
                payment.setStatus("SETTLED");
                payment.setSettledAt(OffsetDateTime.now());
                payment.setVersion(newVersion);
                paymentRepository.save(payment);

                PaymentStatusHistory history = new PaymentStatusHistory();
                history.setPayment(payment);
                history.setFromStatus(oldStatus);
                history.setToStatus("SETTLED");
                history.setReason("Settled in batch: " + savedBatch.getSettlementReference());
                history.setPaymentVersion(newVersion);
                history.setOccurredAt(payment.getSettledAt());
                paymentStatusHistoryRepository.save(history);
            }

            settlementCounter.increment();
            log.info("Generated settlement batch {} for merchant {} with {} payments",
                    savedBatch.getSettlementReference(), merchant.getName(), capturedPayments.size());
        }
    }
}
