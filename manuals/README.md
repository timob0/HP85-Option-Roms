# Pocket guides for HP-85 option ROMs

These editable LaTeX pocket guides provide a compact, independently designed reference based on the layout conventions of the original HP-85 Pocket Guide (small portrait format, orange syntax headings, command descriptions and examples). They do not reproduce HP's artwork.

## Build locally

Install a standard LaTeX distribution with \`pdflatex\` and run from this directory:

\`\`\`sh
pdflatex -interaction=nonstopmode SIMON85-pocket-guide.tex
pdflatex -interaction=nonstopmode SIMON85-pocket-guide.tex
pdflatex -interaction=nonstopmode PRINTER85-pocket-guide.tex
pdflatex -interaction=nonstopmode PRINTER85-pocket-guide.tex
pdflatex -interaction=nonstopmode CPM85-pocket-guide.tex
pdflatex -interaction=nonstopmode CPM85-pocket-guide.tex
\`\`\`

PDFs are local build outputs; commit only the \`.tex\` sources and shared \`pocketguide.sty\`.

## Maintenance rules

- Update the corresponding guide **in the same PR** whenever a BASIC keyword, parameter, error code, printer driver, setup step, or feature version changes.
- Check every guide's command list against the source ROM's public keyword table (SIMON85: \`src/SIMON85_rom.asm\`; PRINTER85: \`src/printer85_rom.asm\`; CPM85: \`src/cpm85.asm\`).
- Keep the version printed on the cover in sync with the source and do not describe an untested feature as hardware-verified.
- Retest build with \`pdflatex\` twice for table of contents, and visually inspect long code lines at pocket-guide width.
- Revisit the EBTKS getting-started section whenever CONFIG.TXT, firmware requirements, SD directory conventions or printer setup changes.

This is an independent project manual, not an HP publication.
