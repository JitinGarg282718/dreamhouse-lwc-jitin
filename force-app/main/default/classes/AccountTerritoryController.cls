public with sharing class AccountTerritoryController {
    private static final Integer DEFAULT_PAGE_SIZE = 5000; // Support up to 5k records as requested
    
    /**
     * Wrapper class for account with territory information
     */
    public class AccountWithTerritory {
        @AuraEnabled public String accountId { get; set; }
        @AuraEnabled public String accountName { get; set; }
        @AuraEnabled public String billingStreet { get; set; }
        @AuraEnabled public String billingCity { get; set; }
        @AuraEnabled public String billingState { get; set; }
        @AuraEnabled public String billingCountry { get; set; }
        @AuraEnabled public String billingPostalCode { get; set; }
        @AuraEnabled public Decimal latitude { get; set; }
        @AuraEnabled public Decimal longitude { get; set; }
        @AuraEnabled public String territoryId { get; set; }
        @AuraEnabled public String territoryName { get; set; }
        @AuraEnabled public String industry { get; set; }
        @AuraEnabled public String accountType { get; set; }
        @AuraEnabled public Decimal annualRevenue { get; set; }
        @AuraEnabled public Integer numberOfEmployees { get; set; }
    }
    
    /**
     * Wrapper class for territory boundary information
     */
    public class TerritoryBoundary {
        @AuraEnabled public String territoryId { get; set; }
        @AuraEnabled public String territoryName { get; set; }
        @AuraEnabled public String boundaryData { get; set; } // GeoJSON string
        @AuraEnabled public String color { get; set; }
        @AuraEnabled public Integer accountCount { get; set; }
    }
    
    /**
     * Get accounts with territory information for mapping
     * @param searchKey Search term for account name or city
     * @param selectedTerritories List of territory IDs to filter by
     * @param selectedIndustries List of industries to filter by
     * @param minRevenue Minimum annual revenue filter
     * @param maxRevenue Maximum annual revenue filter
     * @param pageSize Number of records to return (max 5000)
     * @return List of accounts with territory information
     */
    @AuraEnabled(cacheable=true scope='global')
    public static List<AccountWithTerritory> getAccountsWithTerritories(
        String searchKey,
        List<String> selectedTerritories,
        List<String> selectedIndustries,
        Decimal minRevenue,
        Decimal maxRevenue,
        Integer pageSize
    ) {
        try {
            // Normalize inputs
            String safeSearchKey = String.isBlank(searchKey) ? '' : searchKey.trim();
            Integer safePageSize = (pageSize != null && pageSize > 0) ? Math.min(pageSize, DEFAULT_PAGE_SIZE) : DEFAULT_PAGE_SIZE;
            String searchPattern = '%' + safeSearchKey + '%';
            
            // Build dynamic SOQL query
            String query = 'SELECT Id, Name, BillingStreet, BillingCity, BillingState, BillingCountry, ' +
                          'BillingPostalCode, BillingLatitude, BillingLongitude, Industry, Type, ' +
                          'AnnualRevenue, NumberOfEmployees ';
            
            // Add territory fields if Territory Management is enabled
            if (isTerritoryManagementEnabled()) {
                query += ', (SELECT Territory2Id, Territory2.Name FROM AccountTerritory2Association) ';
            }
            
            query += 'FROM Account WHERE ';
            
            // Add search filter
            if (!String.isBlank(safeSearchKey)) {
                query += '(Name LIKE :searchPattern OR BillingCity LIKE :searchPattern) AND ';
            }
            
            // Add location filter (only accounts with coordinates)
            query += 'BillingLatitude != null AND BillingLongitude != null ';
            
            // Add industry filter
            if (selectedIndustries != null && !selectedIndustries.isEmpty()) {
                query += 'AND Industry IN :selectedIndustries ';
            }
            
            // Add revenue filters
            if (minRevenue != null) {
                query += 'AND AnnualRevenue >= :minRevenue ';
            }
            if (maxRevenue != null) {
                query += 'AND AnnualRevenue <= :maxRevenue ';
            }
            
            query += 'WITH USER_MODE ORDER BY Name LIMIT :safePageSize';
            
            List<Account> accounts = Database.query(query);
            List<AccountWithTerritory> result = new List<AccountWithTerritory>();
            
            for (Account acc : accounts) {
                AccountWithTerritory awt = new AccountWithTerritory();
                awt.accountId = acc.Id;
                awt.accountName = acc.Name;
                awt.billingStreet = acc.BillingStreet;
                awt.billingCity = acc.BillingCity;
                awt.billingState = acc.BillingState;
                awt.billingCountry = acc.BillingCountry;
                awt.billingPostalCode = acc.BillingPostalCode;
                awt.latitude = acc.BillingLatitude;
                awt.longitude = acc.BillingLongitude;
                awt.industry = acc.Industry;
                awt.accountType = acc.Type;
                awt.annualRevenue = acc.AnnualRevenue;
                awt.numberOfEmployees = acc.NumberOfEmployees;
                
                // Set territory information if available
                if (isTerritoryManagementEnabled() && acc.AccountTerritory2Association != null && !acc.AccountTerritory2Association.isEmpty()) {
                    awt.territoryId = acc.AccountTerritory2Association[0].Territory2Id;
                    awt.territoryName = acc.AccountTerritory2Association[0].Territory2.Name;
                } else {
                    awt.territoryId = 'NO_TERRITORY';
                    awt.territoryName = 'No Territory Assigned';
                }
                
                // Apply territory filter if specified
                if (selectedTerritories != null && !selectedTerritories.isEmpty()) {
                    if (selectedTerritories.contains(awt.territoryId)) {
                        result.add(awt);
                    }
                } else {
                    result.add(awt);
                }
            }
            
            return result;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving accounts: ' + e.getMessage());
        }
    }
    
    /**
     * Get territory boundaries for map display
     * @return List of territory boundary information
     */
    @AuraEnabled(cacheable=true scope='global')
    public static List<TerritoryBoundary> getTerritoryBoundaries() {
        try {
            List<TerritoryBoundary> boundaries = new List<TerritoryBoundary>();
            
            if (!isTerritoryManagementEnabled()) {
                return boundaries;
            }
            
            // Get territories with account counts
            List<Territory2> territories = [
                SELECT Id, Name, 
                    (SELECT COUNT() FROM AccountTerritory2Association WHERE Account.BillingLatitude != null AND Account.BillingLongitude != null)
                FROM Territory2 
                WHERE DeveloperName != 'Global'
                WITH USER_MODE
                ORDER BY Name
            ];
            
            // Generate colors for territories
            List<String> colors = generateTerritoryColors(territories.size());
            
            for (Integer i = 0; i < territories.size(); i++) {
                Territory2 territory = territories[i];
                TerritoryBoundary boundary = new TerritoryBoundary();
                boundary.territoryId = territory.Id;
                boundary.territoryName = territory.Name;
                boundary.color = colors[i];
                boundary.accountCount = territory.AccountTerritory2Association.size();
                
                // For now, we'll create circular boundaries around territory centers
                // In a real implementation, you'd store actual boundary coordinates
                boundary.boundaryData = generateTerritoryBoundary(territory.Id, territory.Name);
                
                boundaries.add(boundary);
            }
            
            return boundaries;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving territory boundaries: ' + e.getMessage());
        }
    }
    
    /**
     * Get available territories for filter dropdown
     * @return List of territory options
     */
    @AuraEnabled(cacheable=true scope='global')
    public static List<Map<String, String>> getTerritoryOptions() {
        try {
            List<Map<String, String>> options = new List<Map<String, String>>();
            
            if (!isTerritoryManagementEnabled()) {
                Map<String, String> noTerritory = new Map<String, String>();
                noTerritory.put('label', 'No Territory Management');
                noTerritory.put('value', 'NO_TERRITORY');
                options.add(noTerritory);
                return options;
            }
            
            List<Territory2> territories = [
                SELECT Id, Name 
                FROM Territory2 
                WHERE DeveloperName != 'Global'
                WITH USER_MODE
                ORDER BY Name
            ];
            
            for (Territory2 territory : territories) {
                Map<String, String> option = new Map<String, String>();
                option.put('label', territory.Name);
                option.put('value', territory.Id);
                options.add(option);
            }
            
            return options;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving territory options: ' + e.getMessage());
        }
    }
    
    /**
     * Check if Territory Management is enabled in the org
     * @return Boolean indicating if Territory Management is enabled
     */
    private static Boolean isTerritoryManagementEnabled() {
        try {
            // Try to query Territory2 object to check if Territory Management is enabled
            List<Territory2> testQuery = [SELECT Id FROM Territory2 LIMIT 1 WITH USER_MODE];
            return true;
        } catch (Exception e) {
            return false;
        }
    }
    
    /**
     * Generate colors for territories
     * @param count Number of colors needed
     * @return List of hex color codes
     */
    private static List<String> generateTerritoryColors(Integer count) {
        List<String> colors = new List<String>{
            '#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4', '#FFEAA7',
            '#DDA0DD', '#98D8C8', '#F7DC6F', '#BB8FCE', '#85C1E9',
            '#F8C471', '#82E0AA', '#F1948A', '#85C1E9', '#D2B4DE',
            '#A3E4D7', '#F9E79F', '#D5A6BD', '#AED6F1', '#A9DFBF'
        };
        
        // If we need more colors than predefined, generate random ones
        while (colors.size() < count) {
            colors.add(generateRandomColor());
        }
        
        return colors;
    }
    
    /**
     * Generate a random hex color
     * @return Random hex color string
     */
    private static String generateRandomColor() {
        Integer r = Math.mod(Math.abs(Crypto.getRandomInteger()), 256);
        Integer g = Math.mod(Math.abs(Crypto.getRandomInteger()), 256);
        Integer b = Math.mod(Math.abs(Crypto.getRandomInteger()), 256);
        
        return '#' + 
               (r < 16 ? '0' : '') + Integer.toHexString(r).toUpperCase() +
               (g < 16 ? '0' : '') + Integer.toHexString(g).toUpperCase() +
               (b < 16 ? '0' : '') + Integer.toHexString(b).toUpperCase();
    }
    
    /**
     * Generate territory boundary data (placeholder implementation)
     * In a real scenario, you would store actual boundary coordinates
     * @param territoryId Territory ID
     * @param territoryName Territory name
     * @return GeoJSON string for territory boundary
     */
    private static String generateTerritoryBoundary(String territoryId, String territoryName) {
        // This is a placeholder - in reality you'd have stored boundary coordinates
        // For demo purposes, we'll create circular boundaries around major cities
        Map<String, List<Decimal>> cityCoordinates = new Map<String, List<Decimal>>{
            'North' => new List<Decimal>{40.7128, -74.0060}, // New York
            'South' => new List<Decimal>{25.7617, -80.1918}, // Miami
            'East' => new List<Decimal>{42.3601, -71.0589},  // Boston
            'West' => new List<Decimal>{34.0522, -118.2437}, // Los Angeles
            'Central' => new List<Decimal>{41.8781, -87.6298} // Chicago
        };
        
        // Default to center of US if no match
        List<Decimal> coordinates = new List<Decimal>{39.8283, -98.5795};
        
        // Try to match territory name with region
        for (String region : cityCoordinates.keySet()) {
            if (territoryName.containsIgnoreCase(region)) {
                coordinates = cityCoordinates.get(region);
                break;
            }
        }
        
        // Create a simple circular boundary (in reality, use actual territory boundaries)
        return '{"type":"Feature","properties":{"name":"' + territoryName + '"},"geometry":{"type":"Point","coordinates":[' + coordinates[1] + ',' + coordinates[0] + ']}}';
    }
}