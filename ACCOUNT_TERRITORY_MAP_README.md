# Account Territory Map Solution

A custom Lightning Web Component solution for displaying accounts with territory boundaries on an interactive map, similar to Salesforce Maps but with support for China-based accounts.

## Features

- **Interactive Map Display**: Shows up to 5,000 accounts on a responsive map
- **Territory Boundaries**: Visualizes territory boundaries with customizable colors
- **China Support**: Includes alternative map tiles for China-based accounts (bypassing legal restrictions)
- **Account Clustering**: Groups nearby accounts for better performance
- **Advanced Filtering**: Filter by territory, country, or search terms
- **Responsive Design**: Works on desktop and mobile devices
- **Real-time Updates**: Reactive data loading with caching support

## Components

### 1. AccountTerritoryMapController (Apex)
- **Purpose**: Backend data controller for retrieving account and territory data
- **Key Methods**:
  - `getAccountTerritoryMapData()`: Main method to retrieve filtered account and territory data
  - `updateTerritoryBoundary()`: Updates territory boundary GeoJSON data
- **Features**:
  - Dynamic SOQL query building
  - Territory boundary processing
  - Map center calculation
  - Support for up to 5,000 records

### 2. accountTerritoryMap (LWC)
- **Purpose**: Main mapping component using Leaflet.js
- **Key Features**:
  - Interactive map with zoom/pan controls
  - Account marker clustering
  - Territory boundary overlays
  - Multiple map tile providers (OpenStreetMap, AutoNavi for China)
  - Real-time filtering and search
  - Configurable display options

### 3. accountTerritoryMapDemo (LWC)
- **Purpose**: Demo component showcasing the mapping functionality
- **Configuration**: Pre-configured with sample settings

## Setup Instructions

### 1. Deploy Components
```bash
sf project deploy start --source-dir force-app/main/default
```

### 2. Configure Remote Site Settings
The following remote sites are automatically configured:
- **OpenStreetMap**: `https://tile.openstreetmap.org`
- **AutoNavi**: `https://webrd01.is.autonavi.com` (for China support)

### 3. Territory2 Custom Fields
The solution adds these custom fields to Territory2:
- **BoundaryGeoJSON__c**: Stores GeoJSON polygon data for territory boundaries
- **Color__c**: Hex color code for territory boundary display
- **Description__c**: Territory description for map popups

### 4. Data Requirements

#### Account Data
Accounts must have:
- `BillingLatitude` and `BillingLongitude` populated
- Territory2 associations configured

#### Territory Data
To display territory boundaries, populate the `BoundaryGeoJSON__c` field with valid GeoJSON polygon data:

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

## Usage

### 1. Add to Lightning Page
1. Edit a Lightning App Page, Home Page, or Record Page
2. Drag the "Account Territory Map" component to the page
3. Configure properties:
   - **Map Height**: Set desired height (e.g., "600px")
   - **Show Filters**: Enable/disable filter controls
   - **Default Countries**: Comma-separated list of countries to filter by default
   - **Max Records**: Maximum number of accounts to display (up to 5000)
   - **Include China**: Whether to include China-based accounts

### 2. Component Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `height` | String | "600px" | Map container height |
| `showFilters` | Boolean | true | Show filter controls |
| `defaultCountries` | String | "" | Default countries filter |
| `maxRecords` | Integer | 5000 | Maximum accounts to display |
| `includeChina` | Boolean | true | Include China accounts |

### 3. Filtering Options

- **Search**: Filter by account name, city, or industry
- **Territories**: Multi-select territory filter
- **Countries**: Multi-select country filter
- **Display Options**:
  - Toggle territory boundaries on/off
  - Enable/disable account clustering
  - Include/exclude China accounts

## Technical Architecture

### Frontend (LWC)
- **Leaflet.js**: Open-source mapping library
- **Marker Clustering**: Groups nearby markers for performance
- **Responsive Design**: SLDS-based styling
- **Event Handling**: Real-time filtering and interaction

### Backend (Apex)
- **Dynamic SOQL**: Builds queries based on filter criteria
- **Territory Management**: Handles Territory2 relationships
- **Data Processing**: Formats data for map consumption
- **Performance Optimization**: Limits and caching

### Map Providers
- **OpenStreetMap**: Primary tile provider
- **AutoNavi**: Alternative for China (legal compliance)
- **Layer Control**: Users can switch between providers

## China Support

This solution specifically addresses the legal constraints that prevent Salesforce Maps from displaying China-based accounts:

1. **Alternative Tile Provider**: Uses AutoNavi tiles for China regions
2. **Flexible Configuration**: Can include/exclude China accounts as needed
3. **Legal Compliance**: Bypasses restrictions by using approved China map services

## Performance Considerations

- **Account Limit**: Maximum 5,000 accounts for optimal performance
- **Marker Clustering**: Automatically groups nearby accounts
- **Lazy Loading**: Map tiles loaded on demand
- **Caching**: Apex methods use `@AuraEnabled(cacheable=true)`

## Customization

### Adding Custom Account Fields
Modify `AccountTerritoryMapController.AccountMapData` to include additional fields:

```apex
@AuraEnabled public String customField { get; set; }
```

Update the SOQL query in `buildAccountQuery()`:
```apex
String query = 'SELECT Id, Name, ..., CustomField__c FROM Account...';
```

### Custom Territory Styling
Modify the color palette in `getTerritoryBoundaries()`:
```apex
List<String> colorPalette = new List<String>{
    '#FF6B6B', '#4ECDC4', '#45B7D1', // Add your colors
};
```

### Additional Map Providers
Add new tile layers in `initializeMap()`:
```javascript
const customLayer = L.tileLayer('https://your-tile-server/{z}/{x}/{y}.png', {
    attribution: '© Your Provider',
    maxZoom: 18
});
```

## Troubleshooting

### Common Issues

1. **Map Not Loading**
   - Check remote site settings are deployed
   - Verify static resource is uploaded correctly

2. **No Accounts Displayed**
   - Ensure accounts have latitude/longitude data
   - Check Territory2 associations are configured

3. **Territory Boundaries Missing**
   - Populate `BoundaryGeoJSON__c` field with valid GeoJSON
   - Verify territory associations exist

4. **Performance Issues**
   - Reduce `maxRecords` property
   - Enable account clustering
   - Use more specific filters

### Debug Steps
1. Check browser console for JavaScript errors
2. Review Apex debug logs for SOQL issues
3. Verify data quality (coordinates, associations)
4. Test with smaller data sets

## Security Considerations

- Uses `WITH USER_MODE` in SOQL queries for security
- Respects field-level security and sharing rules
- Static resources served with public cache control
- Remote sites configured with SSL only

## Browser Support

- Chrome 60+
- Firefox 55+
- Safari 12+
- Edge 79+
- Mobile browsers (iOS/Android)

## License

This solution uses open-source libraries:
- Leaflet.js (BSD 2-Clause License)
- Leaflet.markercluster (MIT License)

## Support

For issues or enhancements:
1. Check troubleshooting section above
2. Review Salesforce developer documentation
3. Test in a sandbox environment first
4. Consider performance implications for large datasets