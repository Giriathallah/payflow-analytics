package com.payflow.generator.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;

@Component
@ConfigurationProperties(prefix = "simulation")
public class GeneratorProperties {

    private boolean enabled = true;
    private long randomSeed = 2026;
    private Payment payment = new Payment();
    private Probabilities probabilities = new Probabilities();
    private Schedules schedules = new Schedules();

    public boolean isEnabled() {
        return enabled;
    }

    public void setEnabled(boolean enabled) {
        this.enabled = enabled;
    }

    public long getRandomSeed() {
        return randomSeed;
    }

    public void setRandomSeed(long randomSeed) {
        this.randomSeed = randomSeed;
    }

    public Payment getPayment() {
        return payment;
    }

    public void setPayment(Payment payment) {
        this.payment = payment;
    }

    public Probabilities getProbabilities() {
        return probabilities;
    }

    public void setProbabilities(Probabilities probabilities) {
        this.probabilities = probabilities;
    }

    public Schedules getSchedules() {
        return schedules;
    }

    public void setSchedules(Schedules schedules) {
        this.schedules = schedules;
    }

    public static class Payment {
        private int transactionsPerSecond = 5;
        private BigDecimal minAmount = new BigDecimal("10000");
        private BigDecimal maxAmount = new BigDecimal("5000000");

        public int getTransactionsPerSecond() {
            return transactionsPerSecond;
        }

        public void setTransactionsPerSecond(int transactionsPerSecond) {
            this.transactionsPerSecond = transactionsPerSecond;
        }

        public BigDecimal getMinAmount() {
            return minAmount;
        }

        public void setMinAmount(BigDecimal minAmount) {
            this.minAmount = minAmount;
        }

        public BigDecimal getMaxAmount() {
            return maxAmount;
        }

        public void setMaxAmount(BigDecimal maxAmount) {
            this.maxAmount = maxAmount;
        }
    }

    public static class Probabilities {
        private double authorizationSuccess = 0.85;
        private double captureSuccess = 0.95;
        private double refund = 0.02;
        private double chargeback = 0.005;
        private double settlementMismatch = 0.01;
        private double duplicateSettlement = 0.002;

        public double getAuthorizationSuccess() {
            return authorizationSuccess;
        }

        public void setAuthorizationSuccess(double authorizationSuccess) {
            this.authorizationSuccess = authorizationSuccess;
        }

        public double getCaptureSuccess() {
            return captureSuccess;
        }

        public void setCaptureSuccess(double captureSuccess) {
            this.captureSuccess = captureSuccess;
        }

        public double getRefund() {
            return refund;
        }

        public void setRefund(double refund) {
            this.refund = refund;
        }

        public double getChargeback() {
            return chargeback;
        }

        public void setChargeback(double chargeback) {
            this.chargeback = chargeback;
        }

        public double getSettlementMismatch() {
            return settlementMismatch;
        }

        public void setSettlementMismatch(double settlementMismatch) {
            this.settlementMismatch = settlementMismatch;
        }

        public double getDuplicateSettlement() {
            return duplicateSettlement;
        }

        public void setDuplicateSettlement(double duplicateSettlement) {
            this.duplicateSettlement = duplicateSettlement;
        }
    }

    public static class Schedules {
        private long paymentGenerationMs = 1000;
        private long lifecycleTransitionMs = 2000;
        private long refundGenerationMs = 10000;
        private long settlementGenerationMs = 60000;

        public long getPaymentGenerationMs() {
            return paymentGenerationMs;
        }

        public void setPaymentGenerationMs(long paymentGenerationMs) {
            this.paymentGenerationMs = paymentGenerationMs;
        }

        public long getLifecycleTransitionMs() {
            return lifecycleTransitionMs;
        }

        public void setLifecycleTransitionMs(long lifecycleTransitionMs) {
            this.lifecycleTransitionMs = lifecycleTransitionMs;
        }

        public long getRefundGenerationMs() {
            return refundGenerationMs;
        }

        public void setRefundGenerationMs(long refundGenerationMs) {
            this.refundGenerationMs = refundGenerationMs;
        }

        public long getSettlementGenerationMs() {
            return settlementGenerationMs;
        }

        public void setSettlementGenerationMs(long settlementGenerationMs) {
            this.settlementGenerationMs = settlementGenerationMs;
        }
    }
}
