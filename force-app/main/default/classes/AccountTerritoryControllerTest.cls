@isTest
public class AccountTerritoryControllerTest {
    
    @TestSetup
    static void makeData() {
        // Create test accounts with geolocation data
        List<Account> testAccounts = new List<Account>();
        
        testAccounts.add(new Account(
            Name = 'Test Account 1',
            BillingStreet = '123 Main St',
            BillingCity = 'San Francisco',
            BillingState = 'CA',
            BillingCountry = 'USA',
            BillingPostalCode = '94105',
            BillingLatitude = 37.7749,
            BillingLongitude = -122.4194,
            Industry = 'Technology',
            Type = 'Customer',
            AnnualRevenue = 1000000,
            NumberOfEmployees = 100
        ));
        
        testAccounts.add(new Account(
            Name = 'Test Account 2',
            BillingStreet = '456 Oak Ave',
            BillingCity = 'New York',
            BillingState = 'NY',
            BillingCountry = 'USA',
            BillingPostalCode = '10001',
            BillingLatitude = 40.7128,
            BillingLongitude = -74.0060,
            Industry = 'Finance',
            Type = 'Prospect',
            AnnualRevenue = 2000000,
            NumberOfEmployees = 200
        ));
        
        testAccounts.add(new Account(
            Name = 'Test Account 3',
            BillingStreet = '789 Pine Rd',
            BillingCity = 'Chicago',
            BillingState = 'IL',
            BillingCountry = 'USA',
            BillingPostalCode = '60601',
            BillingLatitude = 41.8781,
            BillingLongitude = -87.6298,
            Industry = 'Manufacturing',
            Type = 'Customer',
            AnnualRevenue = 500000,
            NumberOfEmployees = 50
        ));
        
        // Account without geolocation (should be filtered out)
        testAccounts.add(new Account(
            Name = 'Test Account No Geo',
            BillingStreet = '999 No Geo St',
            BillingCity = 'Unknown',
            BillingState = 'XX',
            BillingCountry = 'USA',
            Industry = 'Other'
        ));
        
        insert testAccounts;
    }
    
    @isTest
    static void testGetAccountsWithTerritories_BasicQuery() {
        Test.startTest();
        
        List<AccountTerritoryController.AccountWithTerritory> results = 
            AccountTerritoryController.getAccountsWithTerritories(
                null, null, null, null, null, null
            );
        
        Test.stopTest();
        
        // Should return 3 accounts (excluding the one without geolocation)
        System.assertEquals(3, results.size(), 'Should return 3 accounts with geolocation');
        
        // Verify account data is properly mapped
        AccountTerritoryController.AccountWithTerritory firstAccount = results[0];
        System.assertNotEquals(null, firstAccount.accountId, 'Account ID should not be null');
        System.assertNotEquals(null, firstAccount.accountName, 'Account name should not be null');
        System.assertNotEquals(null, firstAccount.latitude, 'Latitude should not be null');
        System.assertNotEquals(null, firstAccount.longitude, 'Longitude should not be null');
    }
    
    @isTest
    static void testGetAccountsWithTerritories_WithSearchKey() {
        Test.startTest();
        
        List<AccountTerritoryController.AccountWithTerritory> results = 
            AccountTerritoryController.getAccountsWithTerritories(
                'San Francisco', null, null, null, null, null
            );
        
        Test.stopTest();
        
        // Should return 1 account matching San Francisco
        System.assertEquals(1, results.size(), 'Should return 1 account matching search');
        System.assert(results[0].accountName.contains('Test Account 1') || 
                     results[0].billingCity.contains('San Francisco'), 
                     'Should match search criteria');
    }
    
    @isTest
    static void testGetAccountsWithTerritories_WithIndustryFilter() {
        Test.startTest();
        
        List<String> industries = new List<String>{'Technology', 'Finance'};
        List<AccountTerritoryController.AccountWithTerritory> results = 
            AccountTerritoryController.getAccountsWithTerritories(
                null, null, industries, null, null, null
            );
        
        Test.stopTest();
        
        // Should return 2 accounts with Technology or Finance industry
        System.assertEquals(2, results.size(), 'Should return 2 accounts with specified industries');
        
        for (AccountTerritoryController.AccountWithTerritory account : results) {
            System.assert(industries.contains(account.industry), 
                         'Account industry should be in filter list');
        }
    }
    
    @isTest
    static void testGetAccountsWithTerritories_WithRevenueFilter() {
        Test.startTest();
        
        List<AccountTerritoryController.AccountWithTerritory> results = 
            AccountTerritoryController.getAccountsWithTerritories(
                null, null, null, 750000, 1500000, null
            );
        
        Test.stopTest();
        
        // Should return 1 account with revenue between 750K and 1.5M
        System.assertEquals(1, results.size(), 'Should return 1 account within revenue range');
        System.assertEquals(1000000, results[0].annualRevenue, 'Should match expected revenue');
    }
    
    @isTest
    static void testGetAccountsWithTerritories_WithPageSize() {
        Test.startTest();
        
        List<AccountTerritoryController.AccountWithTerritory> results = 
            AccountTerritoryController.getAccountsWithTerritories(
                null, null, null, null, null, 2
            );
        
        Test.stopTest();
        
        // Should return maximum 2 accounts due to page size limit
        System.assert(results.size() <= 2, 'Should respect page size limit');
    }
    
    @isTest
    static void testGetTerritoryBoundaries() {
        Test.startTest();
        
        List<AccountTerritoryController.TerritoryBoundary> results = 
            AccountTerritoryController.getTerritoryBoundaries();
        
        Test.stopTest();
        
        // This will return empty list if Territory Management is not enabled
        // In orgs with Territory Management, it would return actual boundaries
        System.assertNotEquals(null, results, 'Results should not be null');
    }
    
    @isTest
    static void testGetTerritoryOptions() {
        Test.startTest();
        
        List<Map<String, String>> results = 
            AccountTerritoryController.getTerritoryOptions();
        
        Test.stopTest();
        
        // Should return at least one option (even if Territory Management is disabled)
        System.assert(results.size() >= 1, 'Should return at least one territory option');
        
        // Verify structure of returned options
        Map<String, String> firstOption = results[0];
        System.assert(firstOption.containsKey('label'), 'Option should have label');
        System.assert(firstOption.containsKey('value'), 'Option should have value');
    }
    
    @isTest
    static void testGetAccountsWithTerritories_ExceptionHandling() {
        Test.startTest();
        
        try {
            // Test with invalid parameters that might cause an exception
            List<AccountTerritoryController.AccountWithTerritory> results = 
                AccountTerritoryController.getAccountsWithTerritories(
                    null, null, null, null, null, -1
                );
            
            // Should handle negative page size gracefully
            System.assertNotEquals(null, results, 'Should handle invalid page size gracefully');
            
        } catch (AuraHandledException e) {
            // Exception handling is working correctly
            System.assert(e.getMessage().contains('Error retrieving accounts'), 
                         'Should throw appropriate error message');
        }
        
        Test.stopTest();
    }
    
    @isTest
    static void testGetTerritoryBoundaries_ExceptionHandling() {
        Test.startTest();
        
        try {
            List<AccountTerritoryController.TerritoryBoundary> results = 
                AccountTerritoryController.getTerritoryBoundaries();
            
            // Should not throw exception even if Territory Management is disabled
            System.assertNotEquals(null, results, 'Should return empty list without error');
            
        } catch (AuraHandledException e) {
            // If exception occurs, verify it has appropriate message
            System.assert(e.getMessage().contains('Error retrieving territory boundaries'), 
                         'Should throw appropriate error message');
        }
        
        Test.stopTest();
    }
    
    @isTest
    static void testAccountWithTerritoryWrapper() {
        Test.startTest();
        
        // Test the wrapper class functionality
        AccountTerritoryController.AccountWithTerritory wrapper = 
            new AccountTerritoryController.AccountWithTerritory();
        
        wrapper.accountId = 'test123';
        wrapper.accountName = 'Test Account';
        wrapper.latitude = 37.7749;
        wrapper.longitude = -122.4194;
        wrapper.territoryId = 'territory123';
        wrapper.territoryName = 'Test Territory';
        
        System.assertEquals('test123', wrapper.accountId, 'Account ID should be set correctly');
        System.assertEquals('Test Account', wrapper.accountName, 'Account name should be set correctly');
        System.assertEquals(37.7749, wrapper.latitude, 'Latitude should be set correctly');
        System.assertEquals(-122.4194, wrapper.longitude, 'Longitude should be set correctly');
        System.assertEquals('territory123', wrapper.territoryId, 'Territory ID should be set correctly');
        System.assertEquals('Test Territory', wrapper.territoryName, 'Territory name should be set correctly');
        
        Test.stopTest();
    }
    
    @isTest
    static void testTerritoryBoundaryWrapper() {
        Test.startTest();
        
        // Test the wrapper class functionality
        AccountTerritoryController.TerritoryBoundary wrapper = 
            new AccountTerritoryController.TerritoryBoundary();
        
        wrapper.territoryId = 'territory123';
        wrapper.territoryName = 'Test Territory';
        wrapper.boundaryData = '{"type":"Feature"}';
        wrapper.color = '#FF0000';
        wrapper.accountCount = 5;
        
        System.assertEquals('territory123', wrapper.territoryId, 'Territory ID should be set correctly');
        System.assertEquals('Test Territory', wrapper.territoryName, 'Territory name should be set correctly');
        System.assertEquals('{"type":"Feature"}', wrapper.boundaryData, 'Boundary data should be set correctly');
        System.assertEquals('#FF0000', wrapper.color, 'Color should be set correctly');
        System.assertEquals(5, wrapper.accountCount, 'Account count should be set correctly');
        
        Test.stopTest();
    }
    
    @isTest
    static void testLargeDataSet() {
        // Test with larger dataset to verify performance
        List<Account> largeAccountList = new List<Account>();
        
        for (Integer i = 0; i < 100; i++) {
            largeAccountList.add(new Account(
                Name = 'Large Test Account ' + i,
                BillingStreet = i + ' Test St',
                BillingCity = 'Test City ' + i,
                BillingState = 'CA',
                BillingCountry = 'USA',
                BillingLatitude = 37.0 + (i * 0.01),
                BillingLongitude = -122.0 - (i * 0.01),
                Industry = 'Technology',
                AnnualRevenue = 100000 + (i * 10000)
            ));
        }
        
        insert largeAccountList;
        
        Test.startTest();
        
        List<AccountTerritoryController.AccountWithTerritory> results = 
            AccountTerritoryController.getAccountsWithTerritories(
                null, null, null, null, null, 50
            );
        
        Test.stopTest();
        
        // Should respect page size limit
        System.assert(results.size() <= 50, 'Should respect page size limit with large dataset');
    }
}