targetScope = 'subscription'

@description('Opt-in switch. False performs no budget write and is the repository default.')
param enableBudgets bool = false

@description('Explicit opt-in for budget emails, independent of budget deployment. False preserves silent cost tracking.')
param enableBudgetNotifications bool = false

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
param ciMonthlyBudgetUsd int = 375

@description('Staging resource group budget scope.')
param stagingResourceGroupName string = 'rg-certigo-staging'
@description('Staging monthly budget in the billing currency.')
@minValue(1)
param stagingMonthlyBudgetUsd int = 70

@description('Production resource group budget scope.')
param prodResourceGroupName string = 'rg-certigo-prod'
@description('Production monthly budget in the billing currency.')
@minValue(1)
param prodMonthlyBudgetUsd int = 55

@description('Development resource group budget scope.')
param devResourceGroupName string = 'rg-certigo-dev'
@description('Development monthly budget in the billing currency.')
@minValue(1)
param devMonthlyBudgetUsd int = 55

@description('Content resource group budget scope.')
param contentResourceGroupName string = 'rg-certigo-content'
@description('Content monthly budget in the billing currency.')
@minValue(1)
param contentMonthlyBudgetUsd int = 25

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

resource contentScope 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  name: contentResourceGroupName
}

module ciBudget 'budget.bicep' = if (enableBudgets) {
  scope: ciScope
  name: 'finops-budget-ci'
  params: {
    alertEmail: alertEmail
    enableBudgetNotifications: enableBudgetNotifications
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
    enableBudgetNotifications: enableBudgetNotifications
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
    enableBudgetNotifications: enableBudgetNotifications
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
    enableBudgetNotifications: enableBudgetNotifications
    budgetName: 'budget-certigo-dev-monthly'
    endDate: budgetEndDate
    monthlyBudgetAmount: devMonthlyBudgetUsd
    startDate: budgetStartDate
  }
}

module contentBudget 'budget.bicep' = if (enableBudgets) {
  scope: contentScope
  name: 'finops-budget-content'
  params: {
    alertEmail: alertEmail
    enableBudgetNotifications: enableBudgetNotifications
    budgetName: 'budget-certigo-content-monthly'
    endDate: budgetEndDate
    monthlyBudgetAmount: contentMonthlyBudgetUsd
    startDate: budgetStartDate
  }
}

output budgetsEnabled bool = enableBudgets
output configuredScopeCount int = 5
