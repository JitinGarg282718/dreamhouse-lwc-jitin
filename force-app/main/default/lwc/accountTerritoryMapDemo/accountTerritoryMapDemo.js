import { LightningElement } from 'lwc';

export default class AccountTerritoryMapDemo extends LightningElement {
    // Demo configuration
    mapHeight = '700px';
    showFilters = true;
    defaultCountries = 'United States, Canada, China';
    maxRecords = 5000;
    includeChina = true;
}