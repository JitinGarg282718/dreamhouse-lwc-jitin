/* global L */
import { LightningElement, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { loadScript, loadStyle } from 'lightning/platformResourceLoader';
import { refreshApex } from '@salesforce/apex';
import LEAFLET from '@salesforce/resourceUrl/leafletjs';
import getAccountsWithTerritories from '@salesforce/apex/AccountTerritoryController.getAccountsWithTerritories';
import getTerritoryBoundaries from '@salesforce/apex/AccountTerritoryController.getTerritoryBoundaries';
import getTerritoryOptions from '@salesforce/apex/AccountTerritoryController.getTerritoryOptions';

const LEAFLET_NOT_LOADED = 0;
const LEAFLET_LOADING = 1;
const LEAFLET_READY = 2;

export default class AccountTerritoryMap extends LightningElement {
    // Map state
    leafletState = LEAFLET_NOT_LOADED;
    map;
    accountLayer;
    territoryLayer;
    
    // Data
    @track accounts = [];
    @track territories = [];
    @track territoryOptions = [];
    
    // Filters
    @track searchKey = '';
    @track selectedTerritories = [];
    @track selectedIndustries = [];
    @track minRevenue = null;
    @track maxRevenue = null;
    @track pageSize = 5000;
    
    // UI state
    @track isLoading = false;
    @track showFilters = false;
    @track accountCount = 0;
    @track territoryCount = 0;
    @track showTerritoryBoundaries = true;
    @track showAccountClusters = true;
    
    // Industry options for filter
    industryOptions = [
        { label: 'Agriculture', value: 'Agriculture' },
        { label: 'Apparel', value: 'Apparel' },
        { label: 'Banking', value: 'Banking' },
        { label: 'Biotechnology', value: 'Biotechnology' },
        { label: 'Chemicals', value: 'Chemicals' },
        { label: 'Communications', value: 'Communications' },
        { label: 'Construction', value: 'Construction' },
        { label: 'Consulting', value: 'Consulting' },
        { label: 'Education', value: 'Education' },
        { label: 'Electronics', value: 'Electronics' },
        { label: 'Energy', value: 'Energy' },
        { label: 'Engineering', value: 'Engineering' },
        { label: 'Entertainment', value: 'Entertainment' },
        { label: 'Environmental', value: 'Environmental' },
        { label: 'Finance', value: 'Finance' },
        { label: 'Food & Beverage', value: 'Food & Beverage' },
        { label: 'Government', value: 'Government' },
        { label: 'Healthcare', value: 'Healthcare' },
        { label: 'Hospitality', value: 'Hospitality' },
        { label: 'Insurance', value: 'Insurance' },
        { label: 'Machinery', value: 'Machinery' },
        { label: 'Manufacturing', value: 'Manufacturing' },
        { label: 'Media', value: 'Media' },
        { label: 'Not For Profit', value: 'Not For Profit' },
        { label: 'Other', value: 'Other' },
        { label: 'Recreation', value: 'Recreation' },
        { label: 'Retail', value: 'Retail' },
        { label: 'Shipping', value: 'Shipping' },
        { label: 'Technology', value: 'Technology' },
        { label: 'Telecommunications', value: 'Telecommunications' },
        { label: 'Transportation', value: 'Transportation' },
        { label: 'Utilities', value: 'Utilities' }
    ];
    
    // Wire methods
    @wire(getTerritoryOptions)
    wiredTerritoryOptions({ error, data }) {
        if (data) {
            this.territoryOptions = data;
        } else if (error) {
            this.showToast('Error', 'Failed to load territory options: ' + error.body.message, 'error');
        }
    }
    
    @wire(getTerritoryBoundaries)
    wiredTerritoryBoundaries({ error, data }) {
        if (data) {
            this.territories = data;
            this.territoryCount = data.length;
            this.displayTerritories();
        } else if (error) {
            this.showToast('Error', 'Failed to load territory boundaries: ' + error.body.message, 'error');
        }
    }
    
    @wire(getAccountsWithTerritories, {
        searchKey: '$searchKey',
        selectedTerritories: '$selectedTerritories',
        selectedIndustries: '$selectedIndustries',
        minRevenue: '$minRevenue',
        maxRevenue: '$maxRevenue',
        pageSize: '$pageSize'
    })
    wiredAccounts(result) {
        this.accountsResult = result;
        const { error, data } = result;
        
        if (data) {
            this.accounts = data;
            this.accountCount = data.length;
            this.displayAccounts();
            this.isLoading = false;
        } else if (error) {
            this.accounts = [];
            this.accountCount = 0;
            this.showToast('Error', 'Failed to load accounts: ' + error.body.message, 'error');
            this.isLoading = false;
        }
    }
    
    async renderedCallback() {
        if (this.leafletState === LEAFLET_NOT_LOADED) {
            await this.initializeLeaflet();
        }
    }
    
    async initializeLeaflet() {
        try {
            this.leafletState = LEAFLET_LOADING;
            
            // Load Leaflet resources
            await Promise.all([
                loadScript(this, `${LEAFLET}/leaflet.js`),
                loadStyle(this, `${LEAFLET}/leaflet.css`)
            ]);
            
            // Initialize map
            const mapElement = this.template.querySelector('.map');
            this.map = L.map(mapElement, {
                zoomControl: true,
                tap: false
            });
            
            // Set initial view - centered on US, but can be changed for China
            this.map.setView([39.8283, -98.5795], 4);
            
            // Add tile layer - using OpenStreetMap (works in China)
            L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
                maxZoom: 19,
                attribution: '© OpenStreetMap contributors'
            }).addTo(this.map);
            
            // For China, you might want to use a Chinese tile service:
            // L.tileLayer('https://webrd01.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}', {
            //     maxZoom: 18,
            //     attribution: '© AutoNavi'
            // }).addTo(this.map);
            
            this.leafletState = LEAFLET_READY;
            
            // Display data
            this.displayTerritories();
            this.displayAccounts();
            
        } catch (error) {
            this.showToast('Error', 'Failed to initialize map: ' + error.message, 'error');
        }
    }
    
    displayTerritories() {
        if (this.leafletState !== LEAFLET_READY || !this.territories || !this.showTerritoryBoundaries) {
            return;
        }
        
        // Remove existing territory layer
        if (this.territoryLayer) {
            this.map.removeLayer(this.territoryLayer);
        }
        
        const territoryFeatures = [];
        
        this.territories.forEach(territory => {
            try {
                const geoData = JSON.parse(territory.boundaryData);
                
                // For now, create circular boundaries around territory centers
                if (geoData.geometry.type === 'Point') {
                    const [lng, lat] = geoData.geometry.coordinates;
                    const circle = L.circle([lat, lng], {
                        radius: 100000, // 100km radius
                        fillColor: territory.color,
                        color: territory.color,
                        weight: 2,
                        opacity: 0.8,
                        fillOpacity: 0.2
                    });
                    
                    circle.bindPopup(`
                        <div class="territory-popup">
                            <h3>${territory.territoryName}</h3>
                            <p><strong>Accounts:</strong> ${territory.accountCount}</p>
                        </div>
                    `);
                    
                    territoryFeatures.push(circle);
                }
            } catch (e) {
                console.error('Error parsing territory boundary data:', e);
            }
        });
        
        if (territoryFeatures.length > 0) {
            this.territoryLayer = L.layerGroup(territoryFeatures);
            this.territoryLayer.addTo(this.map);
        }
    }
    
    displayAccounts() {
        if (this.leafletState !== LEAFLET_READY || !this.accounts) {
            return;
        }
        
        // Remove existing account layer
        if (this.accountLayer) {
            this.map.removeLayer(this.accountLayer);
        }
        
        // Create account markers
        const markers = this.accounts.map(account => {
            // Get territory color for account marker
            const territory = this.territories.find(t => t.territoryId === account.territoryId);
            const markerColor = territory ? territory.color : '#666666';
            
            // Create custom icon
            const icon = L.divIcon({
                className: 'account-marker',
                html: `<div style="background-color: ${markerColor}; width: 12px; height: 12px; border-radius: 50%; border: 2px solid white; box-shadow: 0 0 4px rgba(0,0,0,0.3);"></div>`,
                iconSize: [16, 16],
                iconAnchor: [8, 8]
            });
            
            const marker = L.marker([account.latitude, account.longitude], { icon });
            
            // Create popup content
            const popupContent = this.createAccountPopup(account);
            marker.bindPopup(popupContent);
            
            // Add click handler
            marker.on('click', () => {
                this.handleAccountClick(account);
            });
            
            return marker;
        });
        
        // Create marker cluster group if clustering is enabled
        if (this.showAccountClusters && markers.length > 0) {
            // Simple clustering - group nearby markers
            this.accountLayer = L.layerGroup(markers);
        } else {
            this.accountLayer = L.layerGroup(markers);
        }
        
        this.accountLayer.addTo(this.map);
        
        // Fit map to show all accounts if there are any
        if (markers.length > 0 && this.accounts.length < 100) {
            const group = new L.featureGroup(markers);
            this.map.fitBounds(group.getBounds().pad(0.1));
        }
    }
    
    createAccountPopup(account) {
        const revenue = account.annualRevenue ? 
            new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', minimumFractionDigits: 0 }).format(account.annualRevenue) : 
            'N/A';
        
        return `
            <div class="account-popup">
                <h3>${account.accountName}</h3>
                <div class="account-details">
                    <p><strong>Territory:</strong> ${account.territoryName}</p>
                    <p><strong>Industry:</strong> ${account.industry || 'N/A'}</p>
                    <p><strong>Type:</strong> ${account.accountType || 'N/A'}</p>
                    <p><strong>Revenue:</strong> ${revenue}</p>
                    <p><strong>Employees:</strong> ${account.numberOfEmployees || 'N/A'}</p>
                    <p><strong>Address:</strong><br>
                       ${account.billingStreet || ''}<br>
                       ${account.billingCity || ''}, ${account.billingState || ''} ${account.billingPostalCode || ''}<br>
                       ${account.billingCountry || ''}
                    </p>
                </div>
                <div class="account-actions">
                    <button class="slds-button slds-button_brand" onclick="window.open('/lightning/r/Account/${account.accountId}/view', '_blank')">
                        View Account
                    </button>
                </div>
            </div>
        `;
    }
    
    handleAccountClick(account) {
        // Dispatch custom event for account selection
        const accountSelectedEvent = new CustomEvent('accountselected', {
            detail: { accountId: account.accountId, account: account }
        });
        this.dispatchEvent(accountSelectedEvent);
    }
    
    // Filter handlers
    handleSearchKeyChange(event) {
        this.searchKey = event.target.value;
        this.isLoading = true;
    }
    
    handleTerritoryChange(event) {
        this.selectedTerritories = event.detail.value;
        this.isLoading = true;
    }
    
    handleIndustryChange(event) {
        this.selectedIndustries = event.detail.value;
        this.isLoading = true;
    }
    
    handleMinRevenueChange(event) {
        this.minRevenue = event.target.value ? parseFloat(event.target.value) : null;
        this.isLoading = true;
    }
    
    handleMaxRevenueChange(event) {
        this.maxRevenue = event.target.value ? parseFloat(event.target.value) : null;
        this.isLoading = true;
    }
    
    handlePageSizeChange(event) {
        this.pageSize = parseInt(event.target.value, 10);
        this.isLoading = true;
    }
    
    // UI handlers
    toggleFilters() {
        this.showFilters = !this.showFilters;
    }
    
    toggleTerritoryBoundaries() {
        this.showTerritoryBoundaries = !this.showTerritoryBoundaries;
        this.displayTerritories();
    }
    
    toggleAccountClusters() {
        this.showAccountClusters = !this.showAccountClusters;
        this.displayAccounts();
    }
    
    clearFilters() {
        this.searchKey = '';
        this.selectedTerritories = [];
        this.selectedIndustries = [];
        this.minRevenue = null;
        this.maxRevenue = null;
        this.pageSize = 5000;
        this.isLoading = true;
        
        // Reset form inputs
        const inputs = this.template.querySelectorAll('lightning-input, lightning-combobox, lightning-dual-listbox');
        inputs.forEach(input => {
            if (input.type === 'number' || input.type === 'search') {
                input.value = '';
            } else if (input.value) {
                input.value = [];
            }
        });
    }
    
    refreshData() {
        this.isLoading = true;
        return refreshApex(this.accountsResult);
    }
    
    exportData() {
        if (this.accounts.length === 0) {
            this.showToast('Warning', 'No data to export', 'warning');
            return;
        }
        
        // Create CSV content
        const headers = ['Account Name', 'Territory', 'Industry', 'Type', 'Revenue', 'Employees', 'City', 'State', 'Country'];
        const csvContent = [
            headers.join(','),
            ...this.accounts.map(account => [
                `"${account.accountName}"`,
                `"${account.territoryName}"`,
                `"${account.industry || ''}"`,
                `"${account.accountType || ''}"`,
                account.annualRevenue || '',
                account.numberOfEmployees || '',
                `"${account.billingCity || ''}"`,
                `"${account.billingState || ''}"`,
                `"${account.billingCountry || ''}"`
            ].join(','))
        ].join('\n');
        
        // Download CSV
        const element = document.createElement('a');
        element.setAttribute('href', 'data:text/csv;charset=utf-8,' + encodeURIComponent(csvContent));
        element.setAttribute('download', 'account-territory-export.csv');
        element.style.display = 'none';
        document.body.appendChild(element);
        element.click();
        document.body.removeChild(element);
        
        this.showToast('Success', 'Data exported successfully', 'success');
    }
    
    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(evt);
    }
    
    // Getters for template
    get hasAccounts() {
        return this.accounts && this.accounts.length > 0;
    }
    
    get hasTerritories() {
        return this.territories && this.territories.length > 0;
    }
    
    get filterButtonLabel() {
        return this.showFilters ? 'Hide Filters' : 'Show Filters';
    }
    
    get boundaryButtonLabel() {
        return this.showTerritoryBoundaries ? 'Hide Boundaries' : 'Show Boundaries';
    }
    
    get clusterButtonLabel() {
        return this.showAccountClusters ? 'Disable Clustering' : 'Enable Clustering';
    }
    
    get pageSizeOptions() {
        return [
            { label: '100', value: 100 },
            { label: '500', value: 500 },
            { label: '1000', value: 1000 },
            { label: '2000', value: 2000 },
            { label: '5000', value: 5000 }
        ];
    }
    
    get territoriesWithColorStyle() {
        return this.territories.map(territory => ({
            ...territory,
            colorStyle: `background-color: ${territory.color};`
        }));
    }
}