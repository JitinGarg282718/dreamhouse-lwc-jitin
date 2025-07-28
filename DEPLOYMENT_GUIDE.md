# Account Territory Map - Deployment Guide

This guide walks you through deploying the Account Territory Map solution to your Salesforce org.

## Prerequisites

- Salesforce CLI installed and configured
- Access to a Salesforce org with appropriate permissions
- Territory Management 2.0 enabled in your org
- Accounts with populated `BillingLatitude` and `BillingLongitude` fields

## Deployment Steps

### 1. Clone and Prepare the Project

```bash
# Navigate to your project directory
cd /your/project/directory

# Verify the project structure
ls force-app/main/default/
```

### 2. Create the Static Resource Archive

The Leaflet library needs to be packaged as a ZIP file for the static resource:

```bash
# Navigate to the leaflet directory
cd force-app/main/default/staticresources/leaflet

# Create a ZIP archive
zip -r ../leaflet.zip .

# Move back to project root
cd ../../../../..
```

### 3. Deploy to Salesforce

```bash
# Deploy all components
sf project deploy start --source-dir force-app/main/default

# Or deploy specific components
sf project deploy start --source-dir force-app/main/default/classes
sf project deploy start --source-dir force-app/main/default/lwc
sf project deploy start --source-dir force-app/main/default/staticresources
sf project deploy start --source-dir force-app/main/default/remoteSiteSettings
sf project deploy start --source-dir force-app/main/default/objects
```

### 4. Verify Deployment

Check that all components are deployed successfully:

```bash
# Check deployment status
sf project deploy report

# List deployed components
sf project list metadata --metadata-type CustomObject
sf project list metadata --metadata-type ApexClass
sf project list metadata --metadata-type LightningComponentBundle
```

### 5. Configure Remote Site Settings

Verify that the remote site settings are active:

1. Go to **Setup > Security > Remote Site Settings**
2. Confirm these entries exist and are active:
   - **OpenStreetMap**: `https://tile.openstreetmap.org`
   - **AutoNavi**: `https://webrd01.is.autonavi.com`

### 6. Set Up Territory Data (Optional)

If you want to display territory boundaries:

1. Go to **Setup > Territory Management**
2. For each territory where you want boundaries:
   - Edit the territory record
   - Populate the **Boundary GeoJSON** field with valid GeoJSON polygon data
   - Set a **Color** value (hex format, e.g., "#FF6B6B")
   - Add a **Description** if desired

Example GeoJSON for New York City area:
```json
{
  "type": "Polygon",
  "coordinates": [[
    [-74.0059, 40.7128],
    [-74.0059, 40.7589],
    [-73.9352, 40.7589],
    [-73.9352, 40.7128],
    [-74.0059, 40.7128]
  ]]
}
```

### 7. Test the Components

#### Option A: Use the Demo Component
1. Go to **Setup > Lightning App Builder**
2. Create a new App Page or edit an existing one
3. Add the **Account Territory Map Demo** component
4. Save and activate the page

#### Option B: Use the Main Component
1. Go to **Setup > Lightning App Builder**
2. Create a new App Page or edit an existing one
3. Add the **Account Territory Map** component
4. Configure the component properties:
   - **Map Height**: "600px"
   - **Show Filters**: true
   - **Default Countries**: "United States, Canada, China"
   - **Max Records**: 5000
   - **Include China**: true
5. Save and activate the page

### 8. Run Tests

Execute the test classes to verify functionality:

```bash
# Run all tests
sf apex run test --test-level RunLocalTests

# Run specific test class
sf apex run test --class-names AccountTerritoryMapControllerTest

# Get test results
sf apex get test --test-run-id <test-run-id>
```

## Post-Deployment Configuration

### 1. Populate Account Location Data

Ensure your accounts have location data:

```sql
-- Check accounts without location data
SELECT Id, Name, BillingCity, BillingCountry, BillingLatitude, BillingLongitude 
FROM Account 
WHERE BillingLatitude = null OR BillingLongitude = null
```

Use Data Loader or a geocoding service to populate missing coordinates.

### 2. Set Up Territory Associations

Ensure accounts are associated with territories:

```sql
-- Check territory associations
SELECT Id, AccountId, Territory2Id, Territory2.Name 
FROM Territory2Association
```

### 3. Configure User Permissions

Grant appropriate permissions:

1. **Territory Management**: Users need access to Territory2 objects
2. **Account Access**: Users need read access to Account records
3. **Custom Fields**: Grant access to the new Territory2 custom fields

### 4. Optimize Performance

For large datasets:

1. **Reduce Max Records**: Set component's `maxRecords` to 1000-2000 for better performance
2. **Enable Clustering**: Keep `showAccountClusters` enabled
3. **Use Filters**: Encourage users to apply territory/country filters
4. **Index Fields**: Consider adding database indexes on frequently filtered fields

## Troubleshooting

### Common Issues

1. **Map Not Loading**
   - Check browser console for JavaScript errors
   - Verify static resource is deployed correctly
   - Confirm remote site settings are active

2. **No Accounts Displayed**
   - Verify accounts have latitude/longitude data
   - Check user permissions on Account object
   - Review territory associations

3. **Territory Boundaries Missing**
   - Confirm `BoundaryGeoJSON__c` field has valid GeoJSON data
   - Check territory associations exist
   - Verify user access to Territory2 custom fields

4. **Performance Issues**
   - Reduce `maxRecords` setting
   - Enable account clustering
   - Apply more specific filters
   - Check for large territory boundary polygons

### Debug Steps

1. **Enable Debug Mode**:
   ```bash
   sf org open --path /lightning/setup/DeployStatus/home
   ```

2. **Check Apex Logs**:
   ```bash
   sf apex log tail --color
   ```

3. **Browser Developer Tools**:
   - Open browser console
   - Check for JavaScript errors
   - Monitor network requests

4. **Test with Sample Data**:
   - Create test accounts with known coordinates
   - Use simple territory boundaries
   - Test with small datasets first

## Maintenance

### Regular Tasks

1. **Monitor Performance**: Check component load times and user feedback
2. **Update Territory Boundaries**: Keep GeoJSON data current
3. **Review Filters**: Adjust default filters based on usage patterns
4. **Update Dependencies**: Keep Leaflet library updated (when needed)

### Backup Considerations

- Export territory boundary data regularly
- Document custom configurations
- Keep deployment scripts updated

## Support Resources

- [Salesforce Lightning Web Components Developer Guide](https://developer.salesforce.com/docs/component-library/documentation/en/lwc)
- [Territory Management Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_objects_territory2.htm)
- [Leaflet.js Documentation](https://leafletjs.com/reference.html)
- [GeoJSON Specification](https://geojson.org/)

## Version History

- **v1.0**: Initial release with basic mapping functionality
- **v1.1**: Added China support and territory boundaries
- **v1.2**: Enhanced filtering and performance optimizations

For questions or issues, refer to the main README.md file or contact your Salesforce administrator.