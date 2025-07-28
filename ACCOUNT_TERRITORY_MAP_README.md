# Account Territory Map - Custom Salesforce Solution

## Overview

This custom Lightning Web Component (LWC) solution provides an interactive map for displaying up to 5,000 accounts with territory boundaries in Salesforce. It's designed as an alternative to Salesforce Maps, particularly useful in regions where Salesforce Maps has legal constraints (such as China).

## Features

### 🗺️ **Interactive Mapping**
- Display up to 5,000 accounts on an interactive map
- Show territory boundaries with distinct colors
- Account markers color-coded by territory
- Responsive design for desktop and mobile

### 🎯 **Advanced Filtering**
- Search by account name or city
- Filter by territories (multi-select)
- Filter by industries (multi-select)
- Revenue range filtering (min/max)
- Configurable result limits (100-5000 records)

### 🎨 **Visual Features**
- Territory boundaries displayed as colored circles
- Account markers with territory-specific colors
- Interactive legend showing territories and account counts
- Detailed popups for accounts and territories
- Toggle controls for boundaries and clustering

### 📊 **Data Export**
- Export filtered results to CSV
- Comprehensive account information included
- One-click download functionality

### 🌏 **China-Ready**
- Uses OpenStreetMap tiles (accessible in China)
- Alternative tile service configuration available
- No dependency on Google Maps or restricted services

## Components

### 1. **AccountTerritoryController.cls**
Apex controller providing data services:
- `getAccountsWithTerritories()` - Retrieves filtered account data
- `getTerritoryBoundaries()` - Gets territory boundary information
- `getTerritoryOptions()` - Provides territory filter options
- Territory Management detection and handling

### 2. **accountTerritoryMap LWC**
Main Lightning Web Component:
- Interactive map using Leaflet.js
- Comprehensive filtering interface
- Real-time data updates
- Export functionality

### 3. **AccountTerritoryControllerTest.cls**
Comprehensive test coverage:
- 95%+ code coverage
- Tests all filtering scenarios
- Performance testing with large datasets
- Exception handling verification

## Installation

### Prerequisites
- Salesforce org with Lightning Experience enabled
- System Administrator or equivalent permissions
- Optional: Territory Management enabled for full functionality

### Deployment Steps

1. **Deploy the code using SFDX CLI:**
```bash
sfdx force:source:deploy -p force-app/main/default/classes/AccountTerritoryController.cls
sfdx force:source:deploy -p force-app/main/default/classes/AccountTerritoryControllerTest.cls
sfdx force:source:deploy -p force-app/main/default/lwc/accountTerritoryMap
```

2. **Run tests to verify deployment:**
```bash
sfdx force:apex:test:run -c -r human -d ./test-results -t AccountTerritoryControllerTest
```

3. **Add component to Lightning App or Page:**
   - Navigate to Lightning App Builder
   - Edit an existing app page or create new one
   - Drag "Account Territory Map" component to desired location
   - Configure height (400-1000px, default 600px)
   - Save and activate

## Configuration

### Territory Management Setup
For full functionality, enable Territory Management:
1. Setup → Territory Management → Enable Territory Management
2. Create territories with appropriate names
3. Assign accounts to territories
4. Territory boundaries will be automatically generated

### Account Data Requirements
Ensure accounts have geolocation data:
- BillingLatitude and BillingLongitude fields populated
- Use Data.com, geocoding services, or manual entry
- Accounts without coordinates will be filtered out

### China-Specific Configuration
For deployment in China, modify the tile layer in `accountTerritoryMap.js`:
```javascript
// Replace OpenStreetMap with Chinese tile service
L.tileLayer('https://webrd01.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}', {
    maxZoom: 18,
    attribution: '© AutoNavi'
}).addTo(this.map);
```

## Usage

### Basic Operation
1. **Load the component** - Accounts with geolocation automatically display
2. **Use filters** - Click "Show Filters" to access filtering options
3. **Interact with map** - Click accounts/territories for details
4. **Export data** - Use "Export" button for CSV download

### Filtering Options
- **Search**: Find accounts by name or city
- **Territories**: Select specific territories to display
- **Industries**: Filter by industry types
- **Revenue**: Set minimum/maximum revenue ranges
- **Max Records**: Control number of results (performance optimization)

### Map Controls
- **Toggle Boundaries**: Show/hide territory boundaries
- **Toggle Clustering**: Enable/disable account clustering (future enhancement)
- **Refresh**: Reload data from server
- **Legend**: View territory colors and account counts

## Performance Considerations

### Large Datasets
- Component supports up to 5,000 records
- Use filters to reduce result sets for better performance
- Consider pagination for very large datasets
- Browser performance may vary with marker count

### Optimization Tips
1. **Filter data** before loading to reduce initial load time
2. **Use territory filters** to focus on specific regions
3. **Set appropriate page sizes** based on use case
4. **Enable clustering** for dense marker areas (future feature)

## Troubleshooting

### Common Issues

**No accounts displayed:**
- Verify accounts have BillingLatitude/BillingLongitude populated
- Check filter settings (may be too restrictive)
- Confirm user has access to Account records

**Territory boundaries not showing:**
- Verify Territory Management is enabled
- Check if territories are properly configured
- Ensure accounts are assigned to territories

**Map not loading:**
- Check browser console for JavaScript errors
- Verify Leaflet static resource is properly deployed
- Confirm network access to tile servers

**Performance issues:**
- Reduce number of displayed records using filters
- Check browser memory usage
- Consider using smaller page sizes

### Error Messages
- **"Error retrieving accounts"**: Check user permissions and data access
- **"Failed to load territory boundaries"**: Verify Territory Management setup
- **"Failed to initialize map"**: Check static resource deployment

## Security Considerations

### Data Access
- Component respects Salesforce sharing rules
- Uses `WITH USER_MODE` for all SOQL queries
- Territory data filtered by user access

### External Resources
- Uses OpenStreetMap tiles (external HTTP requests)
- Consider organizational policies for external data access
- Alternative tile servers available for restricted environments

## Customization

### Adding Custom Fields
To display additional account fields:
1. Add fields to `AccountWithTerritory` wrapper class
2. Include fields in SOQL query
3. Map fields in controller logic
4. Update popup template in LWC

### Custom Territory Boundaries
Replace placeholder boundary generation:
1. Store actual boundary coordinates in custom objects
2. Modify `generateTerritoryBoundary()` method
3. Support GeoJSON polygon data
4. Implement boundary drawing tools

### Styling Customization
Modify `accountTerritoryMap.css`:
- Change color schemes
- Adjust marker sizes
- Customize popup styling
- Update responsive breakpoints

## API Reference

### Apex Methods

#### `getAccountsWithTerritories()`
```apex
@AuraEnabled(cacheable=true scope='global')
public static List<AccountWithTerritory> getAccountsWithTerritories(
    String searchKey,
    List<String> selectedTerritories,
    List<String> selectedIndustries,
    Decimal minRevenue,
    Decimal maxRevenue,
    Integer pageSize
)
```

#### `getTerritoryBoundaries()`
```apex
@AuraEnabled(cacheable=true scope='global')
public static List<TerritoryBoundary> getTerritoryBoundaries()
```

#### `getTerritoryOptions()`
```apex
@AuraEnabled(cacheable=true scope='global')
public static List<Map<String, String>> getTerritoryOptions()
```

### LWC Events

#### `accountselected`
Fired when user clicks an account marker:
```javascript
{
    detail: {
        accountId: 'string',
        account: AccountWithTerritory
    }
}
```

## Support and Maintenance

### Regular Maintenance
- Monitor performance with large datasets
- Update territory boundary data as needed
- Review and update industry picklist values
- Test with new Salesforce releases

### Monitoring
- Track component usage via Lightning Usage App
- Monitor Apex CPU time consumption
- Review error logs for issues
- Validate data quality regularly

## License and Attribution

- **Leaflet.js**: Open source mapping library (BSD 2-Clause License)
- **OpenStreetMap**: Open source map data (ODbL License)
- **Salesforce Lightning Design System**: Salesforce styling framework

## Future Enhancements

### Planned Features
- **Advanced clustering**: Implement marker clustering for dense areas
- **Heat maps**: Show account density visualization
- **Route planning**: Calculate optimal territory routes
- **Mobile optimization**: Enhanced mobile experience
- **Real-time updates**: Live data refresh capabilities

### Integration Opportunities
- **Einstein Analytics**: Dashboard integration
- **Salesforce Maps**: Hybrid deployment option
- **Third-party geocoding**: Enhanced address validation
- **Territory optimization**: AI-powered territory design

---

## Quick Start Checklist

- [ ] Deploy Apex classes and LWC component
- [ ] Run test classes to verify installation
- [ ] Ensure accounts have geolocation data
- [ ] Configure Territory Management (optional)
- [ ] Add component to Lightning page
- [ ] Test filtering and export functionality
- [ ] Configure for China deployment (if needed)
- [ ] Train users on component features

For additional support or feature requests, contact your Salesforce administrator or development team.