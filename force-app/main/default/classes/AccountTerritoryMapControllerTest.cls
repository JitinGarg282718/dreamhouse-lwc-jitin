@isTest
public class AccountTerritoryMapControllerTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test accounts with location data
        List<Account> testAccounts = new List<Account>();
        
        // US Account
        Account usAccount = new Account(
            Name = 'Test US Account',
            BillingStreet = '123 Main St',
            BillingCity = 'New York',
            BillingState = 'NY',
            BillingCountry = 'United States',
            BillingLatitude = 40.7128,
            BillingLongitude = -74.0060,
            Industry = 'Technology',
            Type = 'Customer',
            NumberOfEmployees = 100,
            AnnualRevenue = 1000000
        );
        testAccounts.add(usAccount);
        
        // China Account
        Account chinaAccount = new Account(
            Name = 'Test China Account',
            BillingStreet = '456 Beijing Rd',
            BillingCity = 'Beijing',
            BillingState = 'Beijing',
            BillingCountry = 'China',
            BillingLatitude = 39.9042,
            BillingLongitude = 116.4074,
            Industry = 'Manufacturing',
            Type = 'Prospect',
            NumberOfEmployees = 500,
            AnnualRevenue = 5000000
        );
        testAccounts.add(chinaAccount);
        
        // Account without location data (should be filtered out)
        Account noLocationAccount = new Account(
            Name = 'Test No Location Account',
            BillingCity = 'Unknown',
            BillingCountry = 'Unknown',
            Industry = 'Other'
        );
        testAccounts.add(noLocationAccount);
        
        insert testAccounts;
    }
    
    @isTest
    static void testGetAccountTerritoryMapData_AllAccounts() {
        Test.startTest();
        
        AccountTerritoryMapController.MapDataResponse response = 
            AccountTerritoryMapController.getAccountTerritoryMapData(
                null, // searchKey
                null, // territoryIds
                null, // countries
                5000, // maxRecords
                true  // includeChina
            );
        
        Test.stopTest();
        
        // Verify response structure
        System.assertNotEquals(null, response, 'Response should not be null');
        System.assertNotEquals(null, response.accounts, 'Accounts list should not be null');
        System.assertNotEquals(null, response.territories, 'Territories list should not be null');
        System.assertNotEquals(null, response.mapCenter, 'Map center should not be null');
        
        // Should return 2 accounts (with location data)
        System.assertEquals(2, response.accounts.size(), 'Should return 2 accounts with location data');
        System.assertEquals(2, response.totalAccounts, 'Total accounts should be 2');
        
        // Verify account data
        List<String> accountNames = new List<String>();
        for (AccountTerritoryMapController.AccountMapData account : response.accounts) {
            accountNames.add(account.name);
            System.assertNotEquals(null, account.latitude, 'Account should have latitude');
            System.assertNotEquals(null, account.longitude, 'Account should have longitude');
        }
        
        System.assert(accountNames.contains('Test US Account'), 'Should contain US account');
        System.assert(accountNames.contains('Test China Account'), 'Should contain China account');
    }
    
    @isTest
    static void testGetAccountTerritoryMapData_ExcludeChina() {
        Test.startTest();
        
        AccountTerritoryMapController.MapDataResponse response = 
            AccountTerritoryMapController.getAccountTerritoryMapData(
                null, // searchKey
                null, // territoryIds
                null, // countries
                5000, // maxRecords
                false // includeChina
            );
        
        Test.stopTest();
        
        // Should return 1 account (excluding China)
        System.assertEquals(1, response.accounts.size(), 'Should return 1 account excluding China');
        System.assertEquals('Test US Account', response.accounts[0].name, 'Should be the US account');
        System.assertNotEquals('China', response.accounts[0].billingCountry, 'Should not include China account');
    }
    
    @isTest
    static void testGetAccountTerritoryMapData_WithSearchKey() {
        Test.startTest();
        
        AccountTerritoryMapController.MapDataResponse response = 
            AccountTerritoryMapController.getAccountTerritoryMapData(
                'China', // searchKey
                null,    // territoryIds
                null,    // countries
                5000,    // maxRecords
                true     // includeChina
            );
        
        Test.stopTest();
        
        // Should return 1 account matching search
        System.assertEquals(1, response.accounts.size(), 'Should return 1 account matching search');
        System.assertEquals('Test China Account', response.accounts[0].name, 'Should be the China account');
    }
    
    @isTest
    static void testGetAccountTerritoryMapData_WithCountryFilter() {
        Test.startTest();
        
        List<String> countries = new List<String>{'United States'};
        AccountTerritoryMapController.MapDataResponse response = 
            AccountTerritoryMapController.getAccountTerritoryMapData(
                null,     // searchKey
                null,     // territoryIds
                countries, // countries
                5000,     // maxRecords
                true      // includeChina
            );
        
        Test.stopTest();
        
        // Should return 1 account from US
        System.assertEquals(1, response.accounts.size(), 'Should return 1 US account');
        System.assertEquals('United States', response.accounts[0].billingCountry, 'Should be US account');
    }
    
    @isTest
    static void testGetAccountTerritoryMapData_WithMaxRecords() {
        Test.startTest();
        
        AccountTerritoryMapController.MapDataResponse response = 
            AccountTerritoryMapController.getAccountTerritoryMapData(
                null, // searchKey
                null, // territoryIds
                null, // countries
                1,    // maxRecords - limit to 1
                true  // includeChina
            );
        
        Test.stopTest();
        
        // Should return only 1 account due to limit
        System.assertEquals(1, response.accounts.size(), 'Should return only 1 account due to limit');
    }
    
    @isTest
    static void testBuildAccountQuery() {
        // This method is private, so we test it indirectly through the main method
        Test.startTest();
        
        // Test with various filter combinations
        AccountTerritoryMapController.MapDataResponse response1 = 
            AccountTerritoryMapController.getAccountTerritoryMapData(
                'Technology', // searchKey
                null,         // territoryIds
                new List<String>{'United States'}, // countries
                5000,         // maxRecords
                false         // includeChina
            );
        
        Test.stopTest();
        
        // Should apply all filters correctly
        System.assertEquals(1, response1.accounts.size(), 'Should apply filters correctly');
        System.assertEquals('Test US Account', response1.accounts[0].name, 'Should match filtered account');
    }
    
    @isTest
    static void testCalculateMapCenter() {
        Test.startTest();
        
        AccountTerritoryMapController.MapDataResponse response = 
            AccountTerritoryMapController.getAccountTerritoryMapData(
                null, // searchKey
                null, // territoryIds
                null, // countries
                5000, // maxRecords
                true  // includeChina
            );
        
        Test.stopTest();
        
        // Verify map center is calculated
        System.assertNotEquals(null, response.mapCenter, 'Map center should be calculated');
        System.assert(response.mapCenter.contains('lat'), 'Map center should contain latitude');
        System.assert(response.mapCenter.contains('lng'), 'Map center should contain longitude');
        
        // Parse JSON to verify structure
        Map<String, Object> centerData = (Map<String, Object>) JSON.deserializeUntyped(response.mapCenter);
        System.assert(centerData.containsKey('lat'), 'Should contain lat key');
        System.assert(centerData.containsKey('lng'), 'Should contain lng key');
    }
    
    @isTest
    static void testGetAccountTerritoryMapData_NoAccounts() {
        // Delete all test accounts
        delete [SELECT Id FROM Account];
        
        Test.startTest();
        
        AccountTerritoryMapController.MapDataResponse response = 
            AccountTerritoryMapController.getAccountTerritoryMapData(
                null, // searchKey
                null, // territoryIds
                null, // countries
                5000, // maxRecords
                true  // includeChina
            );
        
        Test.stopTest();
        
        // Should return empty response
        System.assertEquals(0, response.accounts.size(), 'Should return no accounts');
        System.assertEquals(0, response.totalAccounts, 'Total accounts should be 0');
        System.assertEquals('{"lat": 20, "lng": 0}', response.mapCenter, 'Should return default center');
    }
    
    @isTest
    static void testGetAccountTerritoryMapData_Exception() {
        Test.startTest();
        
        try {
            // Test with invalid parameters that might cause an exception
            AccountTerritoryMapController.MapDataResponse response = 
                AccountTerritoryMapController.getAccountTerritoryMapData(
                    null,  // searchKey
                    null,  // territoryIds
                    null,  // countries
                    -1,    // maxRecords - invalid
                    true   // includeChina
                );
            
            // Should still work with invalid maxRecords (normalized to default)
            System.assertNotEquals(null, response, 'Should handle invalid parameters gracefully');
        } catch (Exception e) {
            // If an exception occurs, it should be an AuraHandledException
            System.assert(e instanceof AuraHandledException, 'Should throw AuraHandledException');
        }
        
        Test.stopTest();
    }
    
    @isTest
    static void testAccountMapDataStructure() {
        Test.startTest();
        
        AccountTerritoryMapController.MapDataResponse response = 
            AccountTerritoryMapController.getAccountTerritoryMapData(
                null, null, null, 5000, true
            );
        
        Test.stopTest();
        
        if (!response.accounts.isEmpty()) {
            AccountTerritoryMapController.AccountMapData account = response.accounts[0];
            
            // Verify all required fields are populated
            System.assertNotEquals(null, account.id, 'Account ID should be populated');
            System.assertNotEquals(null, account.name, 'Account name should be populated');
            System.assertNotEquals(null, account.billingCountry, 'Billing country should be populated');
            System.assertNotEquals(null, account.latitude, 'Latitude should be populated');
            System.assertNotEquals(null, account.longitude, 'Longitude should be populated');
        }
    }
}