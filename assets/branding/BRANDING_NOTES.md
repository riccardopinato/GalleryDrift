# Gallery Drift — icon first
Original, hand-authored vector geometries built specifically for the product.
Design-App checked: ICONE/MATRICE_APP_ICONE.md links reusable UI component symbols, but has no approved launcher mark for Gallery Drift; no stock Gentleface icon is copied.
Intent: layered frames = gallery of visual moments; paired family language with other Drift product but distinct backgrounds/palettes. 
Source SVG: app_icon_master.svg, app_icon_foreground.svg, app_icon_monochrome.svg.
Colors: #112A30; optimized simple silhouette, no artificial glow or stock Flutter glyph.
Build: scripts/install_brand_icon.py installed only AFTER Flutter shell creation; creates Android legacy density icons, adaptive icon and themed monochrome.
Evidence: source generated and CI gates required; physical launcher and 32px shelf screenshot not certified until device QA.
