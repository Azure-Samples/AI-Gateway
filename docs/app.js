// Global state
let labs = [];
let filteredLabs = [];
let selectedCategories = new Set();
let selectedServices = new Set();

// GitHub repository info for raw images
const GITHUB_REPO = 'Azure-Samples/AI-Gateway';
const GITHUB_BRANCH = 'main';
const GITHUB_RAW_BASE = `https://raw.githubusercontent.com/${GITHUB_REPO}/${GITHUB_BRANCH}`;

// Initialize the application
async function init() {
    try {
        const response = await fetch('labs-config.json');
        labs = await response.json();
        filteredLabs = [...labs];
        
        renderFilters();
        renderLabs();
        setupEventListeners();
    } catch (error) {
        console.error('Error loading labs configuration:', error);
        document.getElementById('labsGrid').innerHTML = 
            '<p class="no-results">Error loading labs. Please check the configuration file.</p>';
    }
}

// Render filter options
function renderFilters() {
    const categories = new Set();
    const services = new Set();
    
    labs.forEach(lab => {
        lab.categories.forEach(cat => categories.add(cat));
        lab.services.forEach(svc => services.add(svc));
    });
    
    renderFilterGroup('categoryFilters', Array.from(categories).sort(), 'category');
    renderFilterGroup('serviceFilters', Array.from(services).sort(), 'service');
}

function renderFilterGroup(containerId, items, type) {
    const container = document.getElementById(containerId);
    container.innerHTML = items.map(item => `
        <div class="filter-item">
            <input type="checkbox" id="${type}-${item.replace(/\s+/g, '-')}" 
                   value="${item}" data-type="${type}">
            <label for="${type}-${item.replace(/\s+/g, '-')}">${item}</label>
        </div>
    `).join('');
}

// Render labs grid
function renderLabs() {
    const grid = document.getElementById('labsGrid');
    const noResults = document.getElementById('noResults');
    const labCount = document.getElementById('labCount');
    
    if (filteredLabs.length === 0) {
        grid.style.display = 'none';
        noResults.style.display = 'block';
        labCount.textContent = '';
        return;
    }
    
    grid.style.display = 'grid';
    noResults.style.display = 'none';
    labCount.textContent = `Showing ${filteredLabs.length} of ${labs.length} labs`;
    
    grid.innerHTML = filteredLabs.map(lab => createLabCard(lab)).join('');
    
    // Add click handlers to cards
    document.querySelectorAll('.lab-card').forEach((card, index) => {
        card.addEventListener('click', () => showLabModal(filteredLabs[index]));
    });
}

function createLabCard(lab) {
    const imageUrl = getImageUrl(lab.architectureDiagram);
    
    return `
        <div class="lab-card" data-lab-id="${lab.id}">
            <img src="${imageUrl}" alt="${lab.name}" class="lab-image" 
                 onerror="this.src='data:image/svg+xml,%3Csvg xmlns=%22http://www.w3.org/2000/svg%22 width=%22400%22 height=%22220%22%3E%3Crect fill=%22%23f0f0f0%22 width=%22400%22 height=%22220%22/%3E%3Ctext fill=%22%23999%22 x=%2250%25%22 y=%2250%25%22 dominant-baseline=%22middle%22 text-anchor=%22middle%22 font-family=%22sans-serif%22 font-size=%2218%22%3E${lab.name}%3C/text%3E%3C/svg%3E'">
            <div class="lab-content">
                <h3 class="lab-title">${lab.name}</h3>
                <p class="lab-description">${lab.shortDescription}</p>
                <div class="lab-tags">
                    ${lab.categories.slice(0, 2).map(cat => 
                        `<span class="tag category">${cat}</span>`
                    ).join('')}
                    ${lab.services.slice(0, 2).map(svc => 
                        `<span class="tag service">${svc}</span>`
                    ).join('')}
                </div>
                <div class="lab-footer">
                    <div class="lab-authors">
                        ${lab.authors.map(author => 
                            `<a href="https://github.com/${author}" target="_blank" class="author-link">@${author}</a>`
                        ).join(', ')}
                    </div>
                </div>
            </div>
        </div>
    `;
}

// Show lab modal
function showLabModal(lab) {
    const modal = document.getElementById('labModal');
    const modalBody = document.getElementById('modalBody');
    const imageUrl = getImageUrl(lab.architectureDiagram);
    
    modalBody.innerHTML = `
        <img src="${imageUrl}" alt="${lab.name}" class="modal-image"
             onerror="this.style.display='none'">
        <h2 class="modal-title">${lab.name}</h2>
        <div class="modal-meta">
            <div class="modal-meta-item">
                <h4>Categories</h4>
                <div class="lab-tags">
                    ${lab.categories.map(cat => 
                        `<span class="tag category">${cat}</span>`
                    ).join('')}
                </div>
            </div>
            <div class="modal-meta-item">
                <h4>Services</h4>
                <div class="lab-tags">
                    ${lab.services.map(svc => 
                        `<span class="tag service">${svc}</span>`
                    ).join('')}
                </div>
            </div>
            <div class="modal-meta-item">
                <h4>Authors</h4>
                <div class="lab-authors">
                    ${lab.authors.map(author => 
                        `<a href="https://github.com/${author}" target="_blank" class="author-link">@${author}</a>`
                    ).join(', ')}
                </div>
            </div>
        </div>
        <div class="modal-description">
            ${lab.detailedDescription}
        </div>
        <div class="modal-actions">
            <a href="${lab.githubPath}" class="btn-primary" target="_blank">
                <svg height="20" width="20" viewBox="0 0 16 16" fill="currentColor">
                    <path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z"/>
                </svg>
                View Lab on GitHub
            </a>
        </div>
    `;
    
    modal.style.display = 'block';
}

// Get full image URL
function getImageUrl(path) {
    if (path.startsWith('http')) {
        return path;
    }
    return `${GITHUB_RAW_BASE}/${path}`;
}

// Filter labs
function filterLabs() {
    const searchTerm = document.getElementById('searchInput').value.toLowerCase();
    
    filteredLabs = labs.filter(lab => {
        // Search filter
        const matchesSearch = !searchTerm || 
            lab.name.toLowerCase().includes(searchTerm) ||
            lab.shortDescription.toLowerCase().includes(searchTerm) ||
            lab.detailedDescription.toLowerCase().includes(searchTerm);
        
        // Category filter
        const matchesCategory = selectedCategories.size === 0 ||
            lab.categories.some(cat => selectedCategories.has(cat));
        
        // Service filter
        const matchesService = selectedServices.size === 0 ||
            lab.services.some(svc => selectedServices.has(svc));
        
        return matchesSearch && matchesCategory && matchesService;
    });
    
    renderLabs();
}

// Setup event listeners
function setupEventListeners() {
    // Search
    document.getElementById('searchInput').addEventListener('input', filterLabs);
    
    // Filter checkboxes
    document.querySelectorAll('input[type="checkbox"]').forEach(checkbox => {
        checkbox.addEventListener('change', (e) => {
            const type = e.target.dataset.type;
            const value = e.target.value;
            
            if (type === 'category') {
                if (e.target.checked) {
                    selectedCategories.add(value);
                } else {
                    selectedCategories.delete(value);
                }
            } else if (type === 'service') {
                if (e.target.checked) {
                    selectedServices.add(value);
                } else {
                    selectedServices.delete(value);
                }
            }
            
            filterLabs();
        });
    });
    
    // Clear filters
    document.getElementById('clearFilters').addEventListener('click', () => {
        selectedCategories.clear();
        selectedServices.clear();
        document.getElementById('searchInput').value = '';
        document.querySelectorAll('input[type="checkbox"]').forEach(cb => cb.checked = false);
        filterLabs();
    });
    
    // Modal close
    const modal = document.getElementById('labModal');
    const closeBtn = document.querySelector('.modal-close');
    
    closeBtn.addEventListener('click', () => {
        modal.style.display = 'none';
    });
    
    window.addEventListener('click', (e) => {
        if (e.target === modal) {
            modal.style.display = 'none';
        }
    });
    
    // ESC key to close modal
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && modal.style.display === 'block') {
            modal.style.display = 'none';
        }
    });
}

// Initialize on page load
document.addEventListener('DOMContentLoaded', init);
