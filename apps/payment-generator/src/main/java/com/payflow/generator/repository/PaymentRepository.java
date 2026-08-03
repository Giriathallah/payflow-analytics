package com.payflow.generator.repository;

import com.payflow.generator.domain.Payment;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface PaymentRepository extends JpaRepository<Payment, UUID> {
    List<Payment> findByStatus(String status, Pageable pageable);
    
    List<Payment> findByStatusIn(List<String> statuses, Pageable pageable);

    @Query("SELECT p FROM Payment p WHERE p.merchant.id = :merchantId AND p.status = 'CAPTURED'")
    List<Payment> findCapturedPaymentsByMerchant(@Param("merchantId") UUID merchantId, Pageable pageable);
}
