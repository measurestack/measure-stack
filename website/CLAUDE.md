   # CLAUDE.md - Website Subdirectory

This file provides guidance to Claude Code (claude.ai/code) when working with the **website subdirectory** of the measureStack analytics project.

## Purpose

This website subdirectory contains the static marketing/documentation website for the measureStack analytics platform. It serves as:

- **Public-facing website** showcasing the measureStack analytics platform
- **Product documentation hub** with guides, API docs, and tutorials
- **Landing page** for potential users and developers
- **GitHub Pages deployment target** for easy hosting

The website complements the main analytics platform (located in parent directory) by providing user-friendly documentation and marketing materials.

## CRITICAL: Research Documents for Website Development

**⚠️ IMPORTANT: Before creating or modifying any website content, ALWAYS consult these research documents in this directory:**

### 📊 EARLY_STAGE_RESEARCH.md
**Essential reading for website strategy**. Contains:
- **Pure open source approach**: No early monetization, paid tiers, or business models
- **GitHub-first strategy**: README as homepage initially
- **5-minute rule**: Time-to-value must be < 5 minutes
- **Developer-first messaging**: Technical benefits over business value
- **Launch strategies**: Conference talks and Hacker News, NOT ProductHunt
- **Anti-patterns**: What kills early projects (premature monetization, over-engineering)
- **Early adopter needs**: 10x improvement, working examples > documentation

### 🎯 VALUE_PROPOSITION.md
**Core positioning and messaging**. Contains:
- **One-line positioning**: "Self-hosted Google Analytics alternative that deploys to your cloud in 5 minutes"
- **5 main value pillars**: Data ownership, privacy, quick setup, performance, cost
- **Target user segments**: Privacy-conscious orgs, enterprises, SaaS companies, agencies, startups
- **Competitive differentiation**: vs Google Analytics, Matomo, PostHog
- **Key features and benefits**: Technical, analytics, and operational advantages
- **Use cases**: E-commerce, content, SaaS, marketing analytics

### 🔍 WEBSITE_RESEARCH.md
**Analysis of successful project websites**. Contains:
- **Positioning evolution**: How projects pivoted (e.g., Supabase: "real-time Postgres" → "Firebase alternative")
- **Homepage structure patterns**: Hero message, social proof, quick start CTA
- **Growth triggers**: What sparks viral growth
- **Comparison analysis**: Plausible, PostHog, Matomo, Supabase, Grafana, n8n, Appsmith
- **Success patterns**: Competitor positioning, 5-minute setups, trust indicators
- **Specific recommendations**: Homepage structure, content strategy, growth multipliers

## Deployment Strategy

### GitHub Pages Deployment
- **Primary deployment**: GitHub Pages via the `measurestack/measure-stack` public repository
- **Branch**: Deploy from `main` branch `/website` directory or dedicated `gh-pages` branch
- **URL Structure**: `https://measurestack.github.io/measure-stack/` (or custom domain)
- **Build Process**: None required - pure static files served directly

### Alternative Deployment Options
- Can be deployed to any static hosting service (Netlify, Vercel, etc.)
- Files can be served directly from a web server
- No build process, compilation, or server-side rendering required

## File Structure

```
website/
├── CLAUDE.md              # This guidance file
├── index.html             # Single-page site (minimal for early stage)
├── css/                   # Stylesheets directory
│   └── style.css         # Single minimal stylesheet
├── js/                    # JavaScript directory (optional)
│   └── main.js           # Minimal interactivity if needed
└── assets/               # Static assets
    └── images/           # Only essential images
        └── logo.svg      # measureStack logo (if needed)
```

## Development Approach (Minimal for Early Stage)

### Technology Stack
Based on research, keep it extremely simple:
- **HTML5**: Single page, semantic markup
- **CSS**: Consider lightweight framework like **Pico CSS** or **Simple.css** (< 10KB)
- **JavaScript**: Optional - only for essential interactivity
- **No build process**: Direct file serving

### Recommended Minimal Frameworks
For early-stage simplicity without sacrificing quality:
- **Pico CSS** (8KB): Semantic HTML styling, no classes needed
- **Simple.css** (4KB): Classless CSS framework
- **Alpine.js** (15KB): If interactivity needed, declarative like Vue
- **Prism.js** (2KB): For code syntax highlighting only

### Design Principles
- **GitHub README priority**: Website is secondary to GitHub presence
- **Developer-focused**: Technical audience, not marketing
- **Fast loading**: < 50KB total page weight
- **No over-engineering**: Single page unless absolutely necessary

### Content Strategy (Early Stage)

**Single page only** (`index.html`) containing:
1. **One-line value prop**: "Self-hosted Google Analytics in 5 minutes"
2. **Deploy command**: Copy-paste ready installation
3. **3-5 key features**: Brief bullet points
4. **GitHub CTA**: Link to repo for everything else
5. **No additional pages**: Documentation lives in GitHub README

## Relationship to Parent Project

### Content Sources
- Pull documentation from `/docs/` directory in parent project
- Reference API endpoints and examples from parent codebase
- Use project README and technical docs as content sources
- Showcase the client SDK (`/static/measure.js`) with integration examples

### Shared Assets
- Brand assets should be consistent with parent project
- Code examples should reflect actual parent project APIs
- Screenshots should show real analytics interface/data
- Link to parent project's GitHub repository for developers

### Version Synchronization
- Website version should stay in sync with parent project version (currently 0.2.0)
- Update documentation when parent project API changes
- Reflect new features added to main analytics platform

## Development Commands

```bash
# Simple development server
python -m http.server 8000
# OR
npx serve .
```

## Content Guidelines

### Writing Style
- **Clear and concise**: Technical but accessible language
- **Developer-focused**: Assume audience has technical background
- **Privacy-emphasized**: Highlight privacy-first approach throughout
- **Action-oriented**: Include clear CTAs and next steps

### Code Examples
- Use actual working code from parent project
- Show realistic implementation scenarios
- Include both basic and advanced usage patterns
- Provide copy-paste ready code snippets

### Visual Design
- **Clean, modern aesthetic**: Reflects technical sophistication
- **Privacy-focused branding**: Emphasize control and ownership
- **Performance-oriented**: Fast loading, optimized images
- **Developer-friendly**: Code syntax highlighting, clear documentation layout

## Key Differentiators to Highlight

Based on parent project documentation:
- **Self-hosted solution**: Full data ownership and control
- **Privacy-compliant**: GDPR ready with consent management
- **High performance**: Built with Bun runtime for speed
- **Real-time analytics**: Immediate event tracking and processing
- **Scalable architecture**: Serverless deployment on Cloud Run
- **Developer-friendly**: Easy integration with comprehensive API

## Files to Create

**Minimal approach per research:**
1. `index.html` - Single page with all content
2. `css/style.css` - Minimal styles (or use Pico CSS CDN)
3. Skip JavaScript unless absolutely needed
4. Skip images/logos unless essential

**DO NOT CREATE:**
- Multiple HTML pages
- Complex JavaScript
- Build configuration
- Documentation pages (use GitHub)

---

**Project**: measureStack Analytics Platform Website
**Version**: 0.2.0
**Last Updated**: September 2025
**Deployment**: GitHub Pages Ready