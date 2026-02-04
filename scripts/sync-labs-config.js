#!/usr/bin/env node
/**
 * Script to sync all lab README frontmatter metadata to docs/labs-config.json
 * 
 * Usage: node scripts/sync-labs-config.js
 * 
 * This script:
 * 1. Scans all labs in the labs/ directory
 * 2. Reads frontmatter from each lab's README.md
 * 3. Updates docs/labs-config.json with the metadata
 * 
 * Can be used for initial setup or to manually sync all labs.
 */

const fs = require('fs');
const path = require('path');

// Try to load js-yaml, provide instructions if not available
let yaml;
try {
  yaml = require('js-yaml');
} catch (e) {
  console.error('Error: js-yaml package is required. Install it with: npm install js-yaml');
  process.exit(1);
}

const REPO_OWNER = 'Azure-Samples';
const REPO_NAME = 'AI-Gateway';
const GITHUB_BASE_URL = `https://github.com/${REPO_OWNER}/${REPO_NAME}/tree/main/labs`;
const LABS_CONFIG_PATH = path.join(__dirname, '..', 'docs', 'labs-config.json');
const LABS_DIR = path.join(__dirname, '..', 'labs');

// Folders to ignore
const IGNORE_FOLDERS = ['_deprecated', 'node_modules', '.git'];

/**
 * Parse YAML frontmatter from markdown content
 */
function parseFrontmatter(content) {
  const match = content.match(/^---\n([\s\S]*?)\n---/);
  if (!match) return null;
  
  try {
    return yaml.load(match[1]);
  } catch (e) {
    return null;
  }
}

/**
 * Get all lab folders that have a README.md or README.MD
 */
function getLabFolders() {
  const folders = [];
  
  if (!fs.existsSync(LABS_DIR)) {
    console.error(`Labs directory not found: ${LABS_DIR}`);
    return folders;
  }

  const entries = fs.readdirSync(LABS_DIR, { withFileTypes: true });
  
  for (const entry of entries) {
    if (!entry.isDirectory()) continue;
    if (IGNORE_FOLDERS.includes(entry.name)) continue;
    
    // Check for README.md or README.MD (case variations)
    const readmePathLower = path.join(LABS_DIR, entry.name, 'README.md');
    const readmePathUpper = path.join(LABS_DIR, entry.name, 'README.MD');
    if (fs.existsSync(readmePathLower) || fs.existsSync(readmePathUpper)) {
      folders.push(entry.name);
    }
  }
  
  return folders.sort();
}

/**
 * Main sync function
 */
function syncLabsConfig() {
  console.log('Syncing labs config...\n');
  
  // Read existing config
  let existingConfig = [];
  if (fs.existsSync(LABS_CONFIG_PATH)) {
    try {
      existingConfig = JSON.parse(fs.readFileSync(LABS_CONFIG_PATH, 'utf8'));
    } catch (e) {
      console.warn('Warning: Could not parse existing config, starting fresh');
    }
  }
  
  // Create map for existing entries
  const configMap = new Map(existingConfig.map(lab => [lab.id, lab]));
  
  // Get all lab folders
  const labFolders = getLabFolders();
  console.log(`Found ${labFolders.length} lab folders\n`);
  
  let added = 0;
  let updated = 0;
  let skipped = 0;
  
  for (const labFolder of labFolders) {
    // Check for README.md or README.MD (case variations)
    let readmePath = path.join(LABS_DIR, labFolder, 'README.md');
    if (!fs.existsSync(readmePath)) {
      readmePath = path.join(LABS_DIR, labFolder, 'README.MD');
    }
    const content = fs.readFileSync(readmePath, 'utf8');
    
    const frontmatter = parseFrontmatter(content);
    
    if (!frontmatter) {
      console.log(`⏭️  ${labFolder}: No frontmatter found, skipping`);
      skipped++;
      continue;
    }
    
    // Build lab entry
    const labEntry = {
      id: labFolder,
      name: frontmatter.name || labFolder,
      architectureDiagram: frontmatter.architectureDiagram || '',
      categories: Array.isArray(frontmatter.categories) ? frontmatter.categories : [],
      services: Array.isArray(frontmatter.services) ? frontmatter.services : [],
      shortDescription: frontmatter.shortDescription || '',
      detailedDescription: frontmatter.detailedDescription || '',
      authors: Array.isArray(frontmatter.authors) ? frontmatter.authors : [],
      tags: Array.isArray(frontmatter.tags) ? frontmatter.tags : [],
      githubPath: `${GITHUB_BASE_URL}/${labFolder}`,
      lastCommitDate: new Date().toISOString()
    };
    
    if (configMap.has(labFolder)) {
      // Preserve last-commit-date if content hasn't changed significantly
      const existing = configMap.get(labFolder);
      
      // Check if metadata has changed
      const hasChanged = 
        existing.name !== labEntry.name ||
        existing.shortDescription !== labEntry.shortDescription ||
        existing.detailedDescription !== labEntry.detailedDescription ||
        JSON.stringify(existing.categories) !== JSON.stringify(labEntry.categories) ||
        JSON.stringify(existing.services) !== JSON.stringify(labEntry.services) ||
        JSON.stringify(existing.authors) !== JSON.stringify(labEntry.authors) ||
        JSON.stringify(existing.tags) !== JSON.stringify(labEntry.tags);
      
      if (hasChanged) {
        configMap.set(labFolder, labEntry);
        console.log(`🔄 ${labFolder}: Updated`);
        updated++;
      } else {
        // Keep existing entry with its last-commit-date
        console.log(`✓  ${labFolder}: No changes`);
      }
    } else {
      configMap.set(labFolder, labEntry);
      console.log(`✅ ${labFolder}: Added`);
      added++;
    }
  }
  
  // Convert to sorted array
  const finalConfig = Array.from(configMap.values()).sort((a, b) => a.id.localeCompare(b.id));
  
  // Write config
  fs.writeFileSync(LABS_CONFIG_PATH, JSON.stringify(finalConfig, null, 2) + '\n');
  
  console.log('\n' + '='.repeat(50));
  console.log(`Summary:`);
  console.log(`  Added:   ${added}`);
  console.log(`  Updated: ${updated}`);
  console.log(`  Skipped: ${skipped} (no frontmatter)`);
  console.log(`  Total:   ${finalConfig.length} labs in config`);
  console.log(`\nConfig written to: ${LABS_CONFIG_PATH}`);
}

// Run the sync
syncLabsConfig();
