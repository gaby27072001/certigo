targetScope = 'resourceGroup'

@description('Stable monthly budget name within the resource group.')
@minLength(1)
param budgetName string

@description('Monthly budget amount in the billing currency.')
@minValue(1)
param monthlyBudgetAmount int

@description('First day of a month in ISO 8601 format.')
@minLength(10)
param startDate string

@description('Budget expiry date in ISO 8601 format.')
@minLength(10)
param endDate string

@description('Notification recipient supplied out-of-band from ALERT_EMAIL.')
@secure()
@minLength(3)
param alertEmail string

resource monthlyBudget 'Microsoft.Consumption/budgets@2023-11-01' = {
  name: budgetName
  properties: {
    amount: monthlyBudgetAmount
    category: 'Cost'
    timeGrain: 'Monthly'
    timePeriod: {
      startDate: startDate
      endDate: endDate
    }
    notifications: {
      actual50: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: 50
        thresholdType: 'Actual'
        contactEmails: [
          alertEmail
        ]
      }
      actual80: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: 80
        thresholdType: 'Actual'
        contactEmails: [
          alertEmail
        ]
      }
      actual100: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: 100
        thresholdType: 'Actual'
        contactEmails: [
          alertEmail
        ]
      }
    }
  }
}

output budgetId string = monthlyBudget.id
