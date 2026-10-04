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

@description('Explicit opt-in for budget emails. False keeps cost tracking and thresholds without sending notifications.')
param enableBudgetNotifications bool = false

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
    // Each amount is calibrated to 1.25x the last complete normal month, so a normal
    // month lands at 80% of the amount. Actual thresholds below 100% would therefore
    // fire every normal month by construction; only the three below can stay silent
    // on observed variation and still fire on a measured acceleration.
    notifications: {
      forecast100: {
        enabled: enableBudgetNotifications
        operator: 'GreaterThan'
        threshold: 100
        thresholdType: 'Forecasted'
        contactEmails: [
          alertEmail
        ]
      }
      forecast200: {
        enabled: enableBudgetNotifications
        operator: 'GreaterThan'
        threshold: 200
        thresholdType: 'Forecasted'
        contactEmails: [
          alertEmail
        ]
      }
      actual100: {
        enabled: enableBudgetNotifications
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
