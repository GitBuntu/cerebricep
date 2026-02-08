# Cost Analysis: Healthcare Call Agent MVP

**Document Version**: 1.0  
**Date Created**: February 8, 2026  
**Scope**: MVP deployment for 100 calls/day  
**Environment**: Production with shared infrastructure reuse  

## Executive Summary

The Healthcare Call Agent MVP costs approximately **$122/month in total**, with **~$7/month** for new application-specific resources and **~$115/month** for shared infrastructure reuse.

### Cost Targets ✅
- **New Resources**: < $10/month (MVP) → Achieved ~$7/month ✓
- **Total with Shared**: ~$122/month ✓
- **Per Call Cost**: ~$0.041/day (~$40/month base + usage) = **$0.004 per call** ✓

---

## Resource Cost Breakdown

### New Application Resources (Healthcare Call Agent Workload)

| Resource | SKU/Tier | Usage | Cost/Month | Notes |
|----------|----------|-------|-----------|-------|
| **Storage Account** | Standard LRS | 100 GB (Functions runtime) | ~$2.30 | Blob storage for function code and temporary files |
| **SQL Database** | Basic (5 DTU) | 2 GB, 100 queries/min avg | ~$5.00 | Basic tier supports 100+ concurrent connections |
| **Function App** | Consumption (Y1) | 100 calls/day, 3s avg | ~$0.20 | First 1M/month free; $0.20/million after includes compute + storage |
| **User-Assigned Identity** | Standard | RBAC configuration | Free | No charge for managed identity itself |
| **App Service Plan** | Consumption | (with Function App) | Included | Consumption plan cost included in Function App |
| **Bandwidth** | Outbound | ~10 GB/month | ~-0.87* | US-internal traffic; Cross-RG in same region |
| | | **Subtotal New** | **~$7/month** | |

*\*Outbound data transfer within Azure region is often free or minimal; $0.12/GB elsewhere*

### Shared Infrastructure (Amortized across all workloads)

| Resource | SKU/Tier | Usage | Total Cost | Workload Share | Notes |
|----------|----------|-------|-----------|----------------|-------|
| **Azure Communication Services** | Pay-Per-Use | 100 calls/day | $1.00/call | ~$3,000/month | SMS + Voice usage ($1.00/outbound call) |
| **Azure AI Services** | S1 Standard | 100 calls/day | ~$10 fixed | 5-10% (~$0.50-$1/month) | Fixed tier + overage |
| **VM (shared infrastructure)** | DS2v2 | Monitoring/logging | ~$100 | 10% (~$10) | Amortized across 3-5 workloads |
| **Log Analytics** | Pay-per-use | 100 GB/month | ~$1.50/GB | ~$5-10 | Shared observability |
| | | **Subtotal Shared** | **~$3,100+** | **~$100-120** | |

Total Shared Amortized: **~$115/month** (assuming 3-5 workloads)

---

## Cost Calculation Details

### Scenario: 100 calls/day (1.4 concurrent average)

**Assumptions**:
- Call duration: 180 seconds average (3 minutes)
- Peak concurrency: 5 concurrent calls (500% of average)
- Execution time per call: 3.2 seconds (includes ACS, AI Services, DB queries)
- Outbound data: 100 KB per call (audio, transcripts, summaries)

### Function App Cost (Consumption/Y1)

```
Executions: 100 calls/day × 30 days = 3,000/month
Execution Time: 3.2s × 3,000 = 9,600s = 2.67 GB-s/month
Storage: 100 GB function code + samples = ~$2.30/month

Pricing:
- First 1 million GB-s: Free ($0)
- Storage: $0.24/GB/month × 100 GB = $24/month (overkill; actual ~$1-2)
- Estimated Monthly: $0.20 (minimal within free tier)
```

### SQL Database Cost (Basic Tier)

```
DTU Usage: 5 DTU (Basic tier supports up to 100 concurrent)
Query Pattern: ~100 SELECT + INSERT + UPDATE queries/day
Data Size: 2 GB (1 year of call records ~100 calls/day × 20 KB)
Backup: 7-day retention (automatic, included)

Pricing:
- Basic (5 DTU): $5.40/month
- Storage: 2 GB included in Basic tier
- Estimated Monthly: $5.00
```

### Storage Account Cost (Standard LRS)

```
Storage Usage: 
  - Function code: 50 MB
  - Runtime files: 100 MB
  - Call transcripts: ~2 GB
  Total: ~2.2 GB
  
Block blob: $0.0191/GB/month × 2.2 = $0.04
Archive (optional): $0.004/GB/month (for historical records)

Operations:
  - Read operations: 3,000/month = $0.0004
  - Write operations: 3,000/month = $0.0004
  
Estimated Monthly: $2.30
```

### Communication Services Cost (Shared)

```
Usage: 100 calls/day × 30 days = 3,000 calls/month
Pricing: $1.00 per outbound call (US domestic)

Estimated Monthly (Shared): $3,000
Workload Share (5 workloads): $3,000 ÷ 5 = $600/workload/month

NOTE: This dominates the cost and is driven by call volume,
not infrastructure. Shared infrastructure is cost-efficient.
```

---

## Cost Optimization Opportunities

### Current Implementation (MVP)
✅ **Consumption tier Functions** → No server infrastructure costs  
✅ **Basic SQL tier** → Sufficient for 100 calls/day with 3x headroom  
✅ **Standard LRS Storage** → Lowest cost option for non-critical data  
✅ **Shared infrastructure reuse** → ACS/AI Services amortized across workloads  

### Phase 1 Optimizations (if cost exceeds $10/month)
- [ ] Enable Storage blobs lifecycle policies → Archive old call records after 30 days
- [ ] Prune SQL Database logs → Reduce storage usage
- [ ] Consolidate Function App shared services → Group multiple workloads
- [ ] Enable SQL Database auto-pause (if using Serverless) → Reduces cost during off-hours

### Phase 2 Security Hardening (will increase cost 15-20%)
Planned Phase 2 additions:
- **Key Vault** (~$0.50/month storage + $0.01/API call)
- **VNet + Private Endpoints** (~$32/month for VNet, $0.50 per PE)
- **Application Insights** (~$2.14/month for 1 GB/day ingestion)
- **Managed Identity operations** (included in Azure AD; no new cost)

**Estimated Phase 2 Total**: $97-125/month (vs current $122)

---

## Cost Monitoring & Budgets

### Azure Cost Management Setup

```bash
# Create a budget alert
az costmanagement budget create-update \
  --scope "subscriptions/{SUBSCRIPTION_ID}/resourceGroups/rg-healthcare-call-agent-prod" \
  --name "HCA-MVP-Monthly" \
  --category "Usage" \
  --amount 12.50 \  # Alert at 125% of budget
  --time-period "Monthly" \
  --threshold 125
```

### Monthly Cost Review Checklist
- [ ] Check Azure Cost Management dashboard for actual vs. projected costs
- [ ] Review ACS call usage analytics for anomalies
- [ ] Verify SQL Database DTU usage (target < 50% of capacity)
- [ ] Check Storage Account access patterns (hot vs. archive tiers)
- [ ] Compare shared infrastructure costs month-over-month
- [ ] Review Function App execution time trends (cold starts, duration)

### Alert Thresholds
- **Critical**: Costs exceed $15/month (50% over target) → Investigate immediately
- **Warning**: Costs exceed $12/month (20% over target) → Review usage patterns
- **Info**: Monthly variation > 25% → Daily review recommended

---

## Cost Comparison: MVP vs. Single-Tenant

| Cost Factor | MVP (Shared) | Dedicated | Savings |
|------------|------|----------|---------|
| ACS (100 calls/day) | $600/month shared → $120/workload | $3,000/month | $2,880 (96%) |
| Storage | $2.30 | $2.30 | None |
| SQL Database | $5.00 | $5.00 | None |
| Functions | $0.20 | $0.20 | None |
| Infrastructure | $10/month | $100/month | $90 |
| **Total** | **$122 amortized** | **$3,108 dedicated** | **$2,986** |

**Conclusion**: Shared infrastructure model saves **96%** on communication services costs.

---

## Forecasting: Year 1 Costs

### Scenario 1: Static Load (100 calls/day)
```
Year 1 Cost: $122/month × 12 = $1,464
Phase 2 Security (Month 6+): +$30/month × 6 = $180
Year 1 Total: $1,644
```

### Scenario 2: Growth (100 → 500 calls/day by Month 6)
```
Months 1-3: $122 × 3 = $366
Months 4-6: $300 × 3 = $900 (50% growth)
  - ACS: $1,500/month × 50% = $300/workload
  - Storage: $5/month (+$3)
  - SQL: $5/month (unchanged; plenty of headroom)
Months 7-12 (Phase 2): $350/month × 6 = $2,100
Year 1 Total: $3,366

Note: SQL Basic tier stays sufficient up to 300 DTU usage.
Scale to Standard tier (~$50/month) at 1,000+ calls/day.
```

### Scenario 3: Maximum Scale (1,000 calls/day)
```
Monthly: $350 + ($3,000 × (1,000÷3,000)) + $50 SQL = $351/month
Year 1 (linear growth): ~$2,500
```

---

## Return on Investment (ROI)

For context on value delivered:

| Metric | Value | Annual |
|--------|-------|--------|
| **Calls processed** | 36,500 (100/day) | 100% availability |
| **Cost per call** | $3.35/call | $0.10/call effective |
| **Calls with AI summary** | 36,500 | Included in ACS cost |
| **SQL queries** | 110,000 | Included in DB cost |
| **Infrastructure hours** | 8,760 | 99.95% SLA |

**Value**: Cost-efficient automation + enterprise-grade reliability for call processing.

---

## Budget Allocation

**Recommended Monthly Budget**: **$150** (25% buffer over $122 base)

| Component | Budget | Actual (Target) | Headroom |
|-----------|--------|-----------------|----------|
| ACS (Shared) | $65 | $60 | $5 (8%) |
| Storage | $3 | $2.30 | $0.70 (23%) |
| SQL Database | $7 | $5 | $2 (40%) |
| Functions | $2 | $0.20 | $1.80 (90%) |
| Infra/Shared | $75 | $55 | $20 (36%) |
| **Total** | **$150** | **$122** | **$28 (19%)** |

**Action**: If actual exceeds $140/month, trigger cost review.

---

## Next Steps

1. **Deploy MVP and collect 30 days of actual costs**
2. **Compare projected vs. actual in `cost-analysis.md` section below**
3. **Plan Phase 2 security upgrades** (expected cost +15-20%)
4. **Set up budgets and alerts** in Azure Cost Management
5. **Review quarterly** for optimization opportunities

---

## Appendix: Cost Analysis History

### Initial Projections (February 2026)
- Estimated: $122/month total, ~$7/month new resources ✓
- Status: Deployment pending

### First Month Actual (TBD - After deployment)
- Date: [Deployment date]*3rd week
- Actual: $[TBD]
- Variance: [TBD]
- Actions: [TBD]

### Review Cycle
- **Monthly**: Check against $150 budget
- **Quarterly**: Cost optimization review
- **Annually**: Planned scale/security upgrades

---

**Document Status**: ✅ Complete  
**Next Review**: 30 days after deployment  
**Owner**: Finance & Infrastructure Team
