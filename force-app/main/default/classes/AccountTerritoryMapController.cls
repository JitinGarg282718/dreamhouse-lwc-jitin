public with sharing class AccountTerritoryMapController {
    
    /**
     * Wrapper class for account data with location information
     */
    public class AccountMapData {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String billingStreet { get; set; }
        @AuraEnabled public String billingCity { get; set; }
        @AuraEnabled public String billingState { get; set; }
        @AuraEnabled public String billingCountry { get; set; }
        @AuraEnabled public Decimal latitude { get; set; }
        @AuraEnabled public Decimal longitude { get; set; }
        @AuraEnabled public String territoryId { get; set; }
        @AuraEnabled public String territoryName { get; set; }
        @AuraEnabled public String industry { get; set; }
        @AuraEnabled public String type { get; set; }
        @AuraEnabled public Integer numberOfEmployees { get; set; }
        @AuraEnabled public Decimal annualRevenue { get; set; }
    }
    
    /**
     * Wrapper class for territory boundary data
     */
    public class TerritoryBoundary {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String boundaryData { get; set; } // GeoJSON polygon data
        @AuraEnabled public String color { get; set; }
        @AuraEnabled public Integer accountCount { get; set; }
        @AuraEnabled public String description { get; set; }
    }
    
    /**
     * Response wrapper for the complete map data
     */
    public class MapDataResponse {
        @AuraEnabled public List<AccountMapData> accounts { get; set; }
        @AuraEnabled public List<TerritoryBoundary> territories { get; set; }
        @AuraEnabled public Integer totalAccounts { get; set; }
        @AuraEnabled public String mapCenter { get; set; } // JSON string with lat/lng
    }
    
    /**
     * Retrieves account and territory data for map visualization
     * @param searchKey Search term for account filtering
     * @param territoryIds List of territory IDs to filter by
     * @param countries List of countries to filter by
     * @param maxRecords Maximum number of accounts to return (default 5000)
     * @param includeChina Whether to include China-based accounts (default true)
     * @return MapDataResponse containing accounts and territory boundaries
     */
    @AuraEnabled(cacheable=true)
    public static MapDataResponse getAccountTerritoryMapData(
        String searchKey,
        List<String> territoryIds,
        List<String> countries,
        Integer maxRecords,
        Boolean includeChina
    ) {
        try {
            // Normalize inputs
            String safeSearchKey = String.isBlank(searchKey) ? '' : searchKey.trim();
            Integer safeMaxRecords = maxRecords != null ? maxRecords : 5000;
            Boolean safeIncludeChina = includeChina != null ? includeChina : true;
            
            MapDataResponse response = new MapDataResponse();
            response.accounts = new List<AccountMapData>();
            response.territories = new List<TerritoryBoundary>();
            
            // Build dynamic SOQL for accounts
            String accountQuery = buildAccountQuery(safeSearchKey, territoryIds, countries, safeIncludeChina, safeMaxRecords);
            List<Account> accounts = Database.query(accountQuery);
            
            // Process accounts
            Set<String> foundTerritoryIds = new Set<String>();
            for (Account acc : accounts) {
                AccountMapData mapData = new AccountMapData();
                mapData.id = acc.Id;
                mapData.name = acc.Name;
                mapData.billingStreet = acc.BillingStreet;
                mapData.billingCity = acc.BillingCity;
                mapData.billingState = acc.BillingState;
                mapData.billingCountry = acc.BillingCountry;
                mapData.latitude = acc.BillingLatitude;
                mapData.longitude = acc.BillingLongitude;
                mapData.industry = acc.Industry;
                mapData.type = acc.Type;
                mapData.numberOfEmployees = acc.NumberOfEmployees;
                mapData.annualRevenue = acc.AnnualRevenue;
                
                // Handle territory assignment (assuming custom field or Territory2 relationship)
                if (acc.Territory2Associations != null && !acc.Territory2Associations.isEmpty()) {
                    mapData.territoryId = acc.Territory2Associations[0].Territory2Id;
                    mapData.territoryName = acc.Territory2Associations[0].Territory2.Name;
                    foundTerritoryIds.add(mapData.territoryId);
                }
                
                response.accounts.add(mapData);
            }
            
            // Get territory boundaries
            if (!foundTerritoryIds.isEmpty()) {
                response.territories = getTerritoryBoundaries(foundTerritoryIds);
            }
            
            response.totalAccounts = response.accounts.size();
            response.mapCenter = calculateMapCenter(response.accounts);
            
            return response;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving map data: ' + e.getMessage());
        }
    }
    
    /**
     * Builds dynamic SOQL query for accounts based on filters
     */
    private static String buildAccountQuery(
        String searchKey, 
        List<String> territoryIds, 
        List<String> countries, 
        Boolean includeChina, 
        Integer maxRecords
    ) {
        String query = 'SELECT Id, Name, BillingStreet, BillingCity, BillingState, BillingCountry, ' +
                      'BillingLatitude, BillingLongitude, Industry, Type, NumberOfEmployees, AnnualRevenue, ' +
                      '(SELECT Territory2Id, Territory2.Name FROM Territory2Associations LIMIT 1) ' +
                      'FROM Account WHERE BillingLatitude != null AND BillingLongitude != null';
        
        List<String> conditions = new List<String>();
        
        // Search key filter
        if (!String.isBlank(searchKey)) {
            String searchPattern = '%' + String.escapeSingleQuotes(searchKey) + '%';
            conditions.add('(Name LIKE \'' + searchPattern + '\' OR BillingCity LIKE \'' + searchPattern + '\' OR Industry LIKE \'' + searchPattern + '\')');
        }
        
        // Territory filter
        if (territoryIds != null && !territoryIds.isEmpty()) {
            String territoryFilter = 'Id IN (SELECT AccountId FROM Territory2Association WHERE Territory2Id IN (';
            for (Integer i = 0; i < territoryIds.size(); i++) {
                territoryFilter += '\'' + String.escapeSingleQuotes(territoryIds[i]) + '\'';
                if (i < territoryIds.size() - 1) {
                    territoryFilter += ',';
                }
            }
            territoryFilter += '))';
            conditions.add(territoryFilter);
        }
        
        // Country filter
        if (countries != null && !countries.isEmpty()) {
            String countryFilter = 'BillingCountry IN (';
            for (Integer i = 0; i < countries.size(); i++) {
                countryFilter += '\'' + String.escapeSingleQuotes(countries[i]) + '\'';
                if (i < countries.size() - 1) {
                    countryFilter += ',';
                }
            }
            countryFilter += ')';
            conditions.add(countryFilter);
        }
        
        // China filter
        if (!includeChina) {
            conditions.add('BillingCountry != \'China\' AND BillingCountry != \'CN\'');
        }
        
        // Add conditions to query
        if (!conditions.isEmpty()) {
            query += ' AND ' + String.join(conditions, ' AND ');
        }
        
        query += ' ORDER BY Name LIMIT ' + maxRecords;
        
        return query;
    }
    
    /**
     * Retrieves territory boundary data
     */
    private static List<TerritoryBoundary> getTerritoryBoundaries(Set<String> territoryIds) {
        List<TerritoryBoundary> boundaries = new List<TerritoryBoundary>();
        
        // Query Territory2 records
        List<Territory2> territories = [
            SELECT Id, Name, Description__c, BoundaryGeoJSON__c, Color__c
            FROM Territory2
            WHERE Id IN :territoryIds
            WITH USER_MODE
        ];
        
        // Create color palette for territories without assigned colors
        List<String> colorPalette = new List<String>{
            '#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4', '#FFEAA7',
            '#DDA0DD', '#98D8C8', '#F7DC6F', '#BB8FCE', '#85C1E9'
        };
        
        Integer colorIndex = 0;
        for (Territory2 territory : territories) {
            TerritoryBoundary boundary = new TerritoryBoundary();
            boundary.id = territory.Id;
            boundary.name = territory.Name;
            boundary.description = territory.Description__c;
            boundary.boundaryData = territory.BoundaryGeoJSON__c;
            
            // Assign color
            if (String.isNotBlank(territory.Color__c)) {
                boundary.color = territory.Color__c;
            } else {
                boundary.color = colorPalette[Math.mod(colorIndex, colorPalette.size())];
                colorIndex++;
            }
            
            // Count accounts in territory
            boundary.accountCount = [
                SELECT COUNT()
                FROM Territory2Association
                WHERE Territory2Id = :territory.Id
            ];
            
            boundaries.add(boundary);
        }
        
        return boundaries;
    }
    
    /**
     * Calculates the center point for the map based on account locations
     */
    private static String calculateMapCenter(List<AccountMapData> accounts) {
        if (accounts.isEmpty()) {
            // Default to world center
            return '{"lat": 20, "lng": 0}';
        }
        
        Decimal totalLat = 0;
        Decimal totalLng = 0;
        Integer validLocationCount = 0;
        
        for (AccountMapData account : accounts) {
            if (account.latitude != null && account.longitude != null) {
                totalLat += account.latitude;
                totalLng += account.longitude;
                validLocationCount++;
            }
        }
        
        if (validLocationCount == 0) {
            return '{"lat": 20, "lng": 0}';
        }
        
        Decimal centerLat = totalLat / validLocationCount;
        Decimal centerLng = totalLng / validLocationCount;
        
        return '{"lat": ' + centerLat + ', "lng": ' + centerLng + '}';
    }
    
    /**
     * Updates territory boundary data
     * @param territoryId Territory ID
     * @param boundaryGeoJSON GeoJSON polygon data
     * @param color Territory color
     * @return Success message
     */
    @AuraEnabled
    public static String updateTerritoryBoundary(String territoryId, String boundaryGeoJSON, String color) {
        try {
            Territory2 territory = [
                SELECT Id, BoundaryGeoJSON__c, Color__c
                FROM Territory2
                WHERE Id = :territoryId
                WITH USER_MODE
                LIMIT 1
            ];
            
            territory.BoundaryGeoJSON__c = boundaryGeoJSON;
            territory.Color__c = color;
            
            update territory;
            
            return 'Territory boundary updated successfully';
            
        } catch (Exception e) {
            throw new AuraHandledException('Error updating territory boundary: ' + e.getMessage());
        }
    }
}