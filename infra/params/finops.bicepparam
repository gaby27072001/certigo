// FinOps guardrails are intentionally independent from the application deployment.
// This file compiles in CI but cannot create a budget until enableBudgets is
// explicitly overridden and alertEmail is injected from ALERT_EMAIL.
using '../finops/main.bicep'

param enableBudgets = false
param budgetStartDate = '2026-09-01'
param budgetEndDate = '2031-09-01'
param ciResourceGroupName = 'rg-certigo-ci'
param ciMonthlyBudgetUsd = 275
param stagingResourceGroupName = 'rg-certigo-staging'
param stagingMonthlyBudgetUsd = 60
param prodResourceGroupName = 'rg-certigo-prod'
param prodMonthlyBudgetUsd = 30
param devResourceGroupName = 'rg-certigo-dev'
param devMonthlyBudgetUsd = 30
