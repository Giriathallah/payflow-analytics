package com.payflow.generator.service;

import com.payflow.generator.config.GeneratorProperties;
import com.payflow.generator.domain.Merchant;
import com.payflow.generator.domain.Payment;
import com.payflow.generator.domain.PaymentMethod;
import com.payflow.generator.domain.PaymentStatusHistory;
import com.payflow.generator.repository.MerchantRepository;
import com.payflow.generator.repository.PaymentMethodRepository;
import com.payflow.generator.repository.PaymentRepository;
import com.payflow.generator.repository.PaymentStatusHistoryRepository;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Random;
import java.util.UUID;

@Service
public class PaymentGenerationService {

    private static final Logger log = LoggerFactory.getLogger(PaymentGenerationService.class);

    private final GeneratorProperties properties;
    private final MerchantRepository merchantRepository;
    private final PaymentMethodRepository paymentMethodRepository;
    private final PaymentRepository paymentRepository;
    private final PaymentStatusHistoryRepository paymentStatusHistoryRepository;
    private final Random random = new Random();
    private final Counter paymentGeneratedCounter;

    public PaymentGenerationService(GeneratorProperties properties,
                                    MerchantRepository merchantRepository,
                                    PaymentMethodRepository paymentMethodRepository,
                                    PaymentRepository paymentRepository,
                                    PaymentStatusHistoryRepository paymentStatusHistoryRepository,
                                    MeterRegistry meterRegistry) {
        this.properties = properties;
        this.merchantRepository = merchantRepository;
        this.paymentMethodRepository = paymentMethodRepository;
        this.paymentRepository = paymentRepository;
        this.paymentStatusHistoryRepository = paymentStatusHistoryRepository;
        this.paymentGeneratedCounter = meterRegistry.counter("payflow.payments.generated");
    }

    @Transactional
    public void generatePaymentsBatch() {
        if (!properties.isEnabled()) {
            return;
        }

        List<Merchant> merchants = merchantRepository.findByIsActiveTrue();
        List<PaymentMethod> paymentMethods = paymentMethodRepository.findByIsActiveTrue();

        if (merchants.isEmpty() || paymentMethods.isEmpty()) {
            log.warn("Cannot generate payments: active merchants or payment methods list is empty.");
            return;
        }

        int count = properties.getPayment().getTransactionsPerSecond();
        for (int i = 0; i < count; i++) {
            Merchant merchant = merchants.get(random.nextInt(merchants.size()));
            PaymentMethod method = paymentMethods.get(random.nextInt(paymentMethods.size()));

            BigDecimal minAmt = properties.getPayment().getMinAmount();
            BigDecimal maxAmt = properties.getPayment().getMaxAmount();
            double randomFactor = random.nextDouble();
            BigDecimal amountRange = maxAmt.subtract(minAmt);
            BigDecimal amount = minAmt.add(amountRange.multiply(BigDecimal.valueOf(randomFactor)))
                    .setScale(2, RoundingMode.HALF_UP);

            BigDecimal feeAmount = amount.multiply(merchant.getFeeRate()).setScale(2, RoundingMode.HALF_UP);
            BigDecimal netAmount = amount.subtract(feeAmount);

            Payment payment = new Payment();
            payment.setMerchant(merchant);
            payment.setPaymentMethod(method);
            payment.setExternalReference("TRX-" + System.currentTimeMillis() + "-" + UUID.randomUUID().toString().substring(0, 8));
            payment.setAmount(amount);
            payment.setFeeAmount(feeAmount);
            payment.setNetAmount(netAmount);
            payment.setCurrency("IDR");
            payment.setStatus("INITIATED");
            payment.setVersion(1);
            payment.setInitiatedAt(OffsetDateTime.now());

            Payment savedPayment = paymentRepository.save(payment);

            PaymentStatusHistory history = new PaymentStatusHistory();
            history.setPayment(savedPayment);
            history.setFromStatus(null);
            history.setToStatus("INITIATED");
            history.setReason("Payment initiated by generator");
            history.setPaymentVersion(1);
            history.setOccurredAt(savedPayment.getInitiatedAt());

            paymentStatusHistoryRepository.save(history);
            paymentGeneratedCounter.increment();
        }

        log.info("Generated batch of {} payments", count);
    }
}
