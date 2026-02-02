# AI Gateway Labs - Static Website

A sleek, modern static website to showcase AI Gateway labs with dynamic configuration.

## 🌟 Features

- **Sleek Modern Design**: Inspired by the Spec2Cloud design with a clean, professional look
- **Dynamic Configuration**: All content managed through a single JSON file
- **Filtering & Search**: Filter labs by categories and services, with real-time search
- **Responsive Design**: Works beautifully on desktop, tablet, and mobile devices
- **GitHub Integration**: Automatically loads images from GitHub raw URLs
- **Modal Details**: Click any lab card to see full details in a modal dialog
- **No Build Required**: Pure HTML/CSS/JS - edit JSON and refresh!

## 📁 File Structure

```
docs/
├── index.html          # Main HTML structure
├── styles.css          # All styling and responsive design
├── app.js              # Application logic and interactivity
├── labs-config.json    # Configuration file with all lab data
└── README.md           # This file
```

## 🚀 Getting Started

### Option 1: Open Locally
Simply open `index.html` in your web browser.

### Option 2: Use a Local Server
```bash
cd docs
python -m http.server 8000
# Visit http://localhost:8000
```

### Option 3: GitHub Pages
1. Push the `docs` folder to your GitHub repository
2. Go to repository Settings → Pages
3. Set source to the `docs` folder
4. Your site will be available at `https://<username>.github.io/<repository>/`

## ⚙️ Configuration

All lab content is managed through the `labs-config.json` file. No rebuild required - just edit and refresh!

### JSON Structure

```json
[
  {
    "id": "unique-lab-id",
    "name": "Lab Name",
    "architectureDiagram": "images/diagram.gif",
    "categories": ["Category1", "Category2"],
    "services": ["Service1", "Service2"],
    "shortDescription": "Brief description for the card",
    "detailedDescription": "Full description shown in the modal",
    "authors": ["github-username"],
    "githubPath": "https://github.com/user/repo/tree/main/labs/lab-folder"
  }
]
```

### Configuration Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `id` | string | Unique identifier for the lab (used for data attributes) |
| `name` | string | Display name of the lab |
| `architectureDiagram` | string | Path to the architecture diagram (relative or full URL) |
| `categories` | array | List of category tags (e.g., "Security", "Performance") |
| `services` | array | List of Azure services used (e.g., "Azure API Management") |
| `shortDescription` | string | Brief description (1-2 sentences) shown on the card |
| `detailedDescription` | string | Full description shown in the modal (supports HTML) |
| `authors` | array | GitHub usernames of the lab authors |
| `githubPath` | string | Full URL to the lab's GitHub location |

### Image Paths

The website automatically handles image paths in two ways:

1. **Relative paths**: `images/my-diagram.gif` → Converted to GitHub raw URL
2. **Absolute URLs**: `https://...` → Used as-is

GitHub raw URL format:
```
https://raw.githubusercontent.com/<owner>/<repo>/<branch>/<path>
```

Update the repository details in `app.js`:
```javascript
const GITHUB_REPO = 'Azure-Samples/AI-Gateway';
const GITHUB_BRANCH = 'main';
```

## 🎨 Customization

### Updating Colors
Edit the CSS variables in `styles.css`:
```css
:root {
    --primary-color: #0078d4;
    --primary-dark: #005a9e;
    --secondary-color: #50e6ff;
    /* ... more colors */
}
```

### Updating Header
Edit the logo and tagline in `index.html`:
```html
<div class="logo">
    <h1>AI Gateway Labs</h1>
    <p class="tagline">Azure API Management ❤️ AI Foundry</p>
</div>
```

### Updating Footer
Edit the footer section in `index.html`:
```html
<footer class="footer">
    <div class="container">
        <p>© Your Organization</p>
        <!-- ... -->
    </div>
</footer>
```

## 🔧 Advanced Configuration

### Adding New Filter Types

1. Add the data to your lab objects in `labs-config.json`
2. Update the `renderFilters()` function in `app.js` to extract and render new filter groups
3. Update the `filterLabs()` function to include the new filter logic

### Custom Styling

All styles are in `styles.css`. The design uses:
- CSS Grid for layouts
- CSS Variables for theming
- Responsive breakpoints at 1024px and 768px
- Smooth transitions and hover effects

## 📝 Adding a New Lab

1. Open `labs-config.json`
2. Add a new object to the array:
```json
{
  "id": "my-new-lab",
  "name": "My New Lab",
  "architectureDiagram": "images/my-lab.gif",
  "categories": ["Your Category"],
  "services": ["Azure Service"],
  "shortDescription": "Quick overview",
  "detailedDescription": "Full details here with <strong>HTML support</strong>",
  "authors": ["yourgithub"],
  "githubPath": "https://github.com/org/repo/tree/main/labs/my-lab"
}
```
3. Save and refresh the browser - your new lab will appear!

## 🌐 Browser Support

- Chrome/Edge (latest)
- Firefox (latest)
- Safari (latest)
- Mobile browsers

## 📄 License

This website structure is part of the AI Gateway project. See the main repository for license details.

## 🤝 Contributing

To add or update lab information:
1. Edit `labs-config.json`
2. Ensure your architecture diagram is in the `images/` folder
3. Test locally
4. Submit a pull request

## 💡 Tips

- **Image optimization**: Keep GIF files under 2MB for fast loading
- **Descriptions**: Use HTML in `detailedDescription` for formatting (paragraphs, lists, etc.)
- **Authors**: Use actual GitHub usernames for working profile links
- **Categories & Services**: Keep naming consistent across labs for better filtering

## 🐛 Troubleshooting

**Images not loading?**
- Check the path in `labs-config.json`
- Verify the GitHub repository and branch in `app.js`
- Ensure images exist in the repository

**Labs not appearing?**
- Check browser console for JavaScript errors
- Validate `labs-config.json` syntax (use a JSON validator)
- Ensure the file is being served properly

**Filters not working?**
- Clear browser cache
- Check that categories/services match exactly between labs
