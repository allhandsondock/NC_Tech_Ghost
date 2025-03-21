const appInsights = require('applicationinsights');
const connectionString = process.env.APPLICATIONINSIGHTS_CONNECTION_STRING;

if (connectionString) {
    console.log('Using Application Insights connection string.');
    appInsights.setup(connectionString).start();
} else {
    console.log('WARNING: Application Insights connection string is not set.');
}