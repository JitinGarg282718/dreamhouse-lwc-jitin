import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { loadScript } from 'lightning/platformResourceLoader';
import getAccountTerritoryMapData from '@salesforce/apex/AccountTerritoryMapController.getAccountTerritoryMapData';
import updateTerritoryBoundary from '@salesforce/apex/AccountTerritoryMapController.updateTerritoryBoundary';
import LEAFLET_RESOURCE from '@salesforce/resourceUrl/leaflet';

export default class AccountTerritoryMap extends LightningElement {
    @api height = '600px';
    @api showFilters = true;
    @api defaultCountries = '';
    @api maxRecords = 5000;
    @api includeChina = true;

    @track mapData = {};
    @track isLoading = true;
    @track error;
    @track searchKey = '';
    @track selectedTerritories = [];
    @track selectedCountries = [];
    @track showTerritoryBoundaries = true;
    @track showAccountClusters = true;

    // Map instance
    map;
    accountMarkers = [];
    territoryLayers = [];
    markerClusterGroup;
    
    // Leaflet loaded flag
    leafletLoaded = false;

    connectedCallback() {
        this.loadLeafletLibrary();
        if (this.defaultCountries) {
            this.selectedCountries = this.defaultCountries.split(',').map(c => c.trim());
        }
    }

    renderedCallback() {
        if (this.leafletLoaded && !this.map) {
            this.initializeMap();
        }
    }

    async loadLeafletLibrary() {
        try {
            await loadScript(this, LEAFLET_RESOURCE + '/leaflet.js');
            await loadScript(this, LEAFLET_RESOURCE + '/leaflet.markercluster.js');
            
            // Load CSS
            const leafletCSS = document.createElement('link');
            leafletCSS.rel = 'stylesheet';
            leafletCSS.href = LEAFLET_RESOURCE + '/leaflet.css';
            document.head.appendChild(leafletCSS);

            const clusterCSS = document.createElement('link');
            clusterCSS.rel = 'stylesheet';
            clusterCSS.href = LEAFLET_RESOURCE + '/MarkerCluster.css';
            document.head.appendChild(clusterCSS);

            const clusterDefaultCSS = document.createElement('link');
            clusterDefaultCSS.rel = 'stylesheet';
            clusterDefaultCSS.href = LEAFLET_RESOURCE + '/MarkerCluster.Default.css';
            document.head.appendChild(clusterDefaultCSS);

            this.leafletLoaded = true;
            
            if (this.template.querySelector('.map-container')) {
                this.initializeMap();
            }
        } catch (error) {
            this.handleError('Error loading map library', error);
        }
    }

    initializeMap() {
        const mapContainer = this.template.querySelector('.map-container');
        if (!mapContainer || this.map) return;

        try {
            // Initialize map
            this.map = L.map(mapContainer, {
                zoomControl: true,
                scrollWheelZoom: true,
                doubleClickZoom: true,
                dragging: true
            }).setView([20, 0], 2);

            // Add tile layers with China support
            const osmLayer = L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
                attribution: '© OpenStreetMap contributors',
                maxZoom: 18
            });

            // Alternative tile layer for China (uses local servers)
            const chinaLayer = L.tileLayer('https://webrd0{s}.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}', {
                attribution: '© AutoNavi',
                maxZoom: 18,
                subdomains: ['1', '2', '3', '4']
            });

            // Create layer control
            const baseMaps = {
                'OpenStreetMap': osmLayer,
                'China Map': chinaLayer
            };

            osmLayer.addTo(this.map);
            L.control.layers(baseMaps).addTo(this.map);

            // Initialize marker cluster group
            this.markerClusterGroup = L.markerClusterGroup({
                chunkedLoading: true,
                maxClusterRadius: 50
            });

            // Load initial data
            this.loadMapData();

        } catch (error) {
            this.handleError('Error initializing map', error);
        }
    }

    @wire(getAccountTerritoryMapData, {
        searchKey: '$searchKey',
        territoryIds: '$selectedTerritories',
        countries: '$selectedCountries',
        maxRecords: '$maxRecords',
        includeChina: '$includeChina'
    })
    wiredMapData({ error, data }) {
        this.isLoading = false;
        if (data) {
            this.mapData = data;
            this.error = undefined;
            this.renderMapData();
        } else if (error) {
            this.handleError('Error loading map data', error);
        }
    }

    async loadMapData() {
        this.isLoading = true;
        try {
            const data = await getAccountTerritoryMapData({
                searchKey: this.searchKey,
                territoryIds: this.selectedTerritories,
                countries: this.selectedCountries,
                maxRecords: this.maxRecords,
                includeChina: this.includeChina
            });
            
            this.mapData = data;
            this.renderMapData();
        } catch (error) {
            this.handleError('Error loading map data', error);
        } finally {
            this.isLoading = false;
        }
    }

    renderMapData() {
        if (!this.map || !this.mapData) return;

        this.clearMapLayers();

        // Render territory boundaries
        if (this.showTerritoryBoundaries && this.mapData.territories) {
            this.renderTerritoryBoundaries();
        }

        // Render account markers
        if (this.mapData.accounts) {
            this.renderAccountMarkers();
        }

        // Adjust map view
        this.adjustMapView();
    }

    renderTerritoryBoundaries() {
        this.mapData.territories.forEach(territory => {
            if (territory.boundaryData) {
                try {
                    const geoJSON = JSON.parse(territory.boundaryData);
                    const layer = L.geoJSON(geoJSON, {
                        style: {
                            color: territory.color || '#3388ff',
                            weight: 2,
                            opacity: 0.8,
                            fillOpacity: 0.2
                        }
                    });

                    layer.bindPopup(`
                        <div>
                            <h3>${territory.name}</h3>
                            <p><strong>Accounts:</strong> ${territory.accountCount}</p>
                            ${territory.description ? `<p>${territory.description}</p>` : ''}
                        </div>
                    `);

                    layer.addTo(this.map);
                    this.territoryLayers.push(layer);
                } catch (error) {
                    console.warn('Invalid GeoJSON for territory:', territory.name, error);
                }
            }
        });
    }

    renderAccountMarkers() {
        const markers = [];

        this.mapData.accounts.forEach(account => {
            if (account.latitude && account.longitude) {
                const marker = L.marker([account.latitude, account.longitude]);
                
                const popupContent = `
                    <div class="account-popup">
                        <h3>${account.name}</h3>
                        <p><strong>Address:</strong> ${this.formatAddress(account)}</p>
                        ${account.industry ? `<p><strong>Industry:</strong> ${account.industry}</p>` : ''}
                        ${account.type ? `<p><strong>Type:</strong> ${account.type}</p>` : ''}
                        ${account.territoryName ? `<p><strong>Territory:</strong> ${account.territoryName}</p>` : ''}
                        ${account.numberOfEmployees ? `<p><strong>Employees:</strong> ${account.numberOfEmployees}</p>` : ''}
                        ${account.annualRevenue ? `<p><strong>Annual Revenue:</strong> $${this.formatCurrency(account.annualRevenue)}</p>` : ''}
                    </div>
                `;

                marker.bindPopup(popupContent);
                markers.push(marker);
            }
        });

        if (this.showAccountClusters) {
            this.markerClusterGroup.clearLayers();
            this.markerClusterGroup.addLayers(markers);
            this.map.addLayer(this.markerClusterGroup);
        } else {
            markers.forEach(marker => marker.addTo(this.map));
            this.accountMarkers = markers;
        }
    }

    adjustMapView() {
        if (!this.mapData.accounts || this.mapData.accounts.length === 0) return;

        if (this.mapData.mapCenter) {
            try {
                const center = JSON.parse(this.mapData.mapCenter);
                this.map.setView([center.lat, center.lng], 6);
            } catch (error) {
                console.warn('Invalid map center data', error);
            }
        }

        // Fit bounds to show all markers
        const group = new L.featureGroup([
            ...this.territoryLayers,
            ...(this.showAccountClusters ? [this.markerClusterGroup] : this.accountMarkers)
        ]);

        if (group.getLayers().length > 0) {
            this.map.fitBounds(group.getBounds(), { padding: [20, 20] });
        }
    }

    clearMapLayers() {
        // Clear territory layers
        this.territoryLayers.forEach(layer => this.map.removeLayer(layer));
        this.territoryLayers = [];

        // Clear account markers
        if (this.markerClusterGroup) {
            this.markerClusterGroup.clearLayers();
        }
        this.accountMarkers.forEach(marker => this.map.removeLayer(marker));
        this.accountMarkers = [];
    }

    // Event handlers
    handleSearchChange(event) {
        this.searchKey = event.target.value;
    }

    handleTerritoryChange(event) {
        this.selectedTerritories = event.detail.value;
    }

    handleCountryChange(event) {
        this.selectedCountries = event.detail.value;
    }

    handleToggleBoundaries(event) {
        this.showTerritoryBoundaries = event.target.checked;
        this.renderMapData();
    }

    handleToggleClusters(event) {
        this.showAccountClusters = event.target.checked;
        this.renderMapData();
    }

    handleToggleChina(event) {
        this.includeChina = event.target.checked;
    }

    handleRefresh() {
        this.loadMapData();
    }

    // Utility methods
    formatAddress(account) {
        const parts = [
            account.billingStreet,
            account.billingCity,
            account.billingState,
            account.billingCountry
        ].filter(part => part);
        return parts.join(', ');
    }

    formatCurrency(amount) {
        return new Intl.NumberFormat('en-US', {
            minimumFractionDigits: 0,
            maximumFractionDigits: 0
        }).format(amount);
    }

    handleError(message, error) {
        console.error(message, error);
        this.error = error;
        this.isLoading = false;
        
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: message + ': ' + (error.body?.message || error.message || 'Unknown error'),
                variant: 'error'
            })
        );
    }

    // Getters for template
    get mapContainerStyle() {
        return `height: ${this.height}; width: 100%;`;
    }

    get totalAccountsText() {
        return this.mapData.totalAccounts 
            ? `Showing ${this.mapData.totalAccounts} accounts`
            : 'No accounts found';
    }

    get territoryOptions() {
        if (!this.mapData.territories) return [];
        return this.mapData.territories.map(territory => ({
            label: `${territory.name} (${territory.accountCount})`,
            value: territory.id
        }));
    }

    get countryOptions() {
        if (!this.mapData.accounts) return [];
        const countries = [...new Set(this.mapData.accounts.map(acc => acc.billingCountry))]
            .filter(country => country)
            .sort();
        return countries.map(country => ({
            label: country,
            value: country
        }));
    }

    // Add color style for territory legend
    get territoriesWithStyle() {
        if (!this.mapData.territories) return [];
        return this.mapData.territories.map(territory => ({
            ...territory,
            colorStyle: `background-color: ${territory.color || '#3388ff'};`
        }));
    }
}