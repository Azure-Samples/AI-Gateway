// Configuration
const BASE_PATH = './';
const DEFAULT_DOC = './0-introduction.md';

// State
let currentDoc = null;

// Initialize the application
async function init() {
    setupEventListeners();
    
    // Load default document or from URL hash
    const hash = window.location.hash.slice(1);
    const docToLoad = hash || DEFAULT_DOC;
    await loadDocument(docToLoad);
}

// Setup event listeners
function setupEventListeners() {
    // Navigation links
    document.querySelectorAll('.nav-link').forEach(link => {
        link.addEventListener('click', async (e) => {
            e.preventDefault();
            const docPath = e.target.getAttribute('data-doc');
            await loadDocument(docPath);
            
            // Update URL hash
            window.location.hash = docPath;
            
            // Update active state
            updateActiveNavLink(docPath);
        });
    });
    
    // Handle browser back/forward
    window.addEventListener('hashchange', async () => {
        const docPath = window.location.hash.slice(1) || DEFAULT_DOC;
        await loadDocument(docPath);
        updateActiveNavLink(docPath);
    });
}

// Update active navigation link
function updateActiveNavLink(docPath) {
    document.querySelectorAll('.nav-link').forEach(link => {
        link.classList.remove('active');
        if (link.getAttribute('data-doc') === docPath) {
            link.classList.add('active');
        }
    });
}

// Load and render markdown document
async function loadDocument(docPath) {
    const contentDiv = document.getElementById('documentContent');
    const loadingDiv = document.getElementById('loadingIndicator');
    const errorDiv = document.getElementById('errorMessage');
    
    // Show loading state
    loadingDiv.style.display = 'flex';
    contentDiv.style.display = 'none';
    errorDiv.style.display = 'none';
    
    try {
        // Fetch markdown file
        const response = await fetch(BASE_PATH + docPath);
        
        if (!response.ok) {
            throw new Error(`Failed to load document: ${response.statusText}`);
        }
        
        let markdown = await response.text();
        
        // Remove frontmatter if present
        markdown = removeFrontmatter(markdown);
        
        // Configure marked options
        marked.setOptions({
            breaks: true,
            gfm: true,
            headerIds: true,
            mangle: false,
            highlight: function(code, lang) {
                if (lang && hljs.getLanguage(lang)) {
                    try {
                        return hljs.highlight(code, { language: lang }).value;
                    } catch (err) {
                        console.error('Highlight error:', err);
                    }
                }
                return hljs.highlightAuto(code).value;
            }
        });
        
        // Convert markdown to HTML
        const html = marked.parse(markdown);
        
        // Process HTML for special elements
        const processedHtml = processHtml(html, docPath);
        
        // Render content
        contentDiv.innerHTML = processedHtml;
        
        // Hide loading, show content
        loadingDiv.style.display = 'none';
        contentDiv.style.display = 'block';
        
        // Generate table of contents
        generateTableOfContents();
        
        // Scroll to top
        window.scrollTo({ top: 0, behavior: 'smooth' });
        
        currentDoc = docPath;
        
    } catch (error) {
        console.error('Error loading document:', error);
        
        // Show error message
        loadingDiv.style.display = 'none';
        errorDiv.style.display = 'block';
        errorDiv.innerHTML = `
            <h3>⚠️ Error Loading Document</h3>
            <p>Could not load: <code>${docPath}</code></p>
            <p>${error.message}</p>
            <button onclick="location.hash='${DEFAULT_DOC}'">Go to Introduction</button>
        `;
    }
}

// Remove YAML frontmatter from markdown
function removeFrontmatter(markdown) {
    const frontmatterRegex = /^---\s*\n([\s\S]*?)\n---\s*\n/;
    return markdown.replace(frontmatterRegex, '');
}

// Process HTML for special elements
function processHtml(html, docPath) {
    let processed = html;
    
    // Fix relative image paths
    const docDir = docPath.substring(0, docPath.lastIndexOf('/') + 1);
    processed = processed.replace(
        /src="(?!http)([^"]+)"/g,
        (match, imagePath) => {
            // Handle paths starting with /
            if (imagePath.startsWith('/')) {
                return `src="${BASE_PATH}${imagePath.slice(1)}"`;
            }
            // Handle relative paths
            const fullPath = docDir + imagePath;
            return `src="${BASE_PATH}${fullPath}"`;
        }
    );
    
    // Process admonitions (:::tip, :::important, etc.)
    processed = processed.replace(
        /:::(tip|important|note|warning)\[(.*?)\]([\s\S]*?):::/g,
        (match, type, title, content) => {
            return `<div class="admonition ${type}">
                <strong>${title}</strong>
                ${content}
            </div>`;
        }
    );
    
    // Make external links open in new tab
    processed = processed.replace(
        /<a href="(https?:\/\/[^"]+)"/g,
        '<a href="$1" target="_blank" rel="noopener noreferrer"'
    );
    
    // Fix internal doc links
    processed = processed.replace(
        /<a href="\.\/([^"]+\.md)"/g,
        (match, linkPath) => {
            const fullPath = docDir + linkPath;
            return `<a href="#${fullPath}"`;
        }
    );
    
    return processed;
}

// Generate table of contents from headings
function generateTableOfContents() {
    const contentDiv = document.getElementById('documentContent');
    const tocDiv = document.getElementById('tableOfContents');
    const tocContainer = document.querySelector('.toc-container');
    
    // Find all h2 and h3 headings
    const headings = contentDiv.querySelectorAll('h2, h3');
    
    if (headings.length === 0) {
        tocContainer.classList.remove('visible');
        return;
    }
    
    let tocHtml = '<ul class="toc">';
    
    headings.forEach((heading, index) => {
        const text = heading.textContent;
        const id = `heading-${index}`;
        heading.id = id;
        
        const level = heading.tagName === 'H2' ? 'toc-h2' : 'toc-h3';
        const indent = heading.tagName === 'H3' ? 'style="padding-left: 1.5rem;"' : '';
        
        tocHtml += `<li><a href="#${id}" class="${level}" ${indent}>${text}</a></li>`;
    });
    
    tocHtml += '</ul>';
    
    tocDiv.innerHTML = tocHtml;
    tocContainer.classList.add('visible');
    
    // Add smooth scroll to TOC links
    tocDiv.querySelectorAll('a').forEach(link => {
        link.addEventListener('click', (e) => {
            e.preventDefault();
            const targetId = link.getAttribute('href').slice(1);
            const targetElement = document.getElementById(targetId);
            
            if (targetElement) {
                targetElement.scrollIntoView({ behavior: 'smooth', block: 'start' });
                
                // Update active TOC link
                tocDiv.querySelectorAll('a').forEach(l => l.classList.remove('active'));
                link.classList.add('active');
            }
        });
    });
    
    // Highlight TOC on scroll
    setupTocScrollHighlight();
}

// Setup scroll-based TOC highlighting
function setupTocScrollHighlight() {
    const contentDiv = document.getElementById('documentContent');
    const headings = contentDiv.querySelectorAll('h2, h3');
    const tocLinks = document.querySelectorAll('.toc a');
    
    if (headings.length === 0 || tocLinks.length === 0) return;
    
    let ticking = false;
    
    window.addEventListener('scroll', () => {
        if (!ticking) {
            window.requestAnimationFrame(() => {
                updateActiveTocLink(headings, tocLinks);
                ticking = false;
            });
            ticking = true;
        }
    });
}

// Update active TOC link based on scroll position
function updateActiveTocLink(headings, tocLinks) {
    let current = '';
    const scrollPos = window.scrollY + 100;
    
    headings.forEach((heading) => {
        const top = heading.offsetTop;
        if (scrollPos >= top) {
            current = heading.id;
        }
    });
    
    tocLinks.forEach((link) => {
        link.classList.remove('active');
        if (link.getAttribute('href') === `#${current}`) {
            link.classList.add('active');
        }
    });
}

// Initialize when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
} else {
    init();
}
