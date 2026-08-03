package com.payflow.generator.repository;

import com.payflow.generator.domain.SettlementItem;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.UUID;

@Repository
public interface SettlementItemRepository extends JpaRepository<SettlementItem, UUID> {
}
