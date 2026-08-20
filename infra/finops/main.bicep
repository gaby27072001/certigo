targetScope = 'subscription'

@description('Opt-in switch. False performs no budget write and is the repository default.')
param enableBudgets bool = false

@description('First day of the first budget month in ISO 8601 format.')
@minLength(10)
param budgetStartDate string

@description('Budget expiry date in ISO 8601 format.')
@minLength(10)
param budgetEndDate string

@description('Notification recipient injected from the existing ALERT_EMAIL environment variable.')
@secure()
param alertEmail string = ''

@description('CI resource group budget scope.')
param ciResourceGroupName string = 'rg-certigo-ci'
@description('CI monthly budget in the billing currency.')
@minValue(1)
param ciMonthlyBudgetUsd int = 275

@description('Staging resource group budget scope.')
param stagingResourceGroupName string = 'rg-certigo-staging'
@description('Staging monthly budget in the billing currency.')
@minValue(1)
param stagingMonthlyBudgetUsd int = 60

@description('Production resource group budget scope.')
param prodResourceGroupName string = 'rg-certigo-prod'
@description('Production monthly budget in the billing currency.')
@minValue(1)
param prodMonthlyBudgetUsd int = 30

@description('Development resource group budget scope.')
param devResourceGroupName string = 'rg-certigo-dev'
@description('Development monthly budget in the billing currency.')
@minValue(1)
param devMonthlyBudgetUsd int = 30

resource ciScope 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  name: ciResourceGroupName
}

resource stagingScope 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  name: stagingResourceGroupName
}

resource prodScope 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  name: prodResourceGroupName
}

resource devScope 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  name: devResourceGroupName
}

module ciBudget 'budget.bicep' = if (enableBudgets) {
  scope: ciScope
  name: 'finops-budget-ci'
  params: {
    alertEmail: alertEmail
    budgetName: 'budget-certigo-ci-monthly'
    endDate: budgetEndDate
    monthlyBudgetAmount: ciMonthlyBudgetUsd
    startDate: budgetStartDate
  }
}

module stagingBudget 'budget.bicep' = if (enableBudgets) {
  scope: stagingScope
  name: 'finops-budget-staging'
  params: {
    alertEmail: alertEmail
    budgetName: 'budget-certigo-staging-monthly'
    endDate: budgetEndDate
    monthlyBudgetAmount: stagingMonthlyBudgetUsd
    startDate: budgetStartDate
  }
}

module prodBudget 'budget.bicep' = if (enableBudgets) {
  scope: prodScope
  name: 'finops-budget-prod'
  params: {
    alertEmail: alertEmail
    budgetName: 'budget-certigo-prod-monthly'
    endDate: budgetEndDate
    monthlyBudgetAmount: prodMonthlyBudgetUsd
    startDate: budgetStartDate
  }
}

module devBudget 'budget.bicep' = if (enableBudgets) {
  scope: devScope
  name: 'finops-budget-dev'
  params: {
    alertEmail: alertEmail
    budgetName: 'budget-certigo-dev-monthly'
    endDate: budgetEndDate
    monthlyBudgetAmount: devMonthlyBudgetUsd
    startDate: budgetStartDate
  }
}

output budgetsEnabled bool = enableBudgets
output configuredScopeCount int = 4
