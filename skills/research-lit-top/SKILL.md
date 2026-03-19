---
name: research-lit-top
description: Search and analyze research papers from top-tier venues (CCF-A conferences and journals). Use when user says "top venue papers", "top conference papers", "best papers on", "top-tier literature", "A-venue survey", or needs a literature review restricted to top venues.
argument-hint: [paper-topic-or-url] — include-preprints: true
allowed-tools: Bash(*), Read, Glob, Grep, WebSearch, WebFetch, Write, Agent, mcp__zotero__*, mcp__obsidian-vault__*
---

# Research Literature Review — Top Venues

Research topic: $ARGUMENTS

## Constants

- **PAPER_LIBRARY** — Local directory containing user's paper collection (PDFs). Check these paths in order:
  1. `papers/` in the current project directory
  2. `literature/` in the current project directory
  3. Custom path specified by user in `CLAUDE.md` under `## Paper Library`
- **MAX_LOCAL_PAPERS = 20** — Maximum number of local PDFs to scan (read first 3 pages each). If more are found, prioritize by filename relevance to the topic.
- **ARXIV_DOWNLOAD = false** — When `true`, download top 3-5 most relevant arXiv PDFs to PAPER_LIBRARY after search. When `false` (default), only fetch metadata (title, abstract, authors) via arXiv API — no files are downloaded.
- **ARXIV_MAX_DOWNLOAD = 5** — Maximum number of PDFs to download when `ARXIV_DOWNLOAD = true`.
- **INCLUDE_PREPRINTS = false** — When `true`, include high-quality arXiv preprints in Table 1 even if not yet published at a top venue. When `false` (default), preprints go to Table 2.

> Overrides:
> - `/research-lit-top "topic" — paper library: ~/my_papers/` — custom local PDF path
> - `/research-lit-top "topic" — sources: zotero, local` — only search Zotero + local PDFs
> - `/research-lit-top "topic" — sources: zotero` — only search Zotero
> - `/research-lit-top "topic" — sources: web` — only search the web (skip all local)
> - `/research-lit-top "topic" — arxiv download: true` — download top relevant arXiv PDFs
> - `/research-lit-top "topic" — arxiv download: true, max download: 10` — download up to 10 PDFs
> - `/research-lit-top "topic" — include-preprints: true` — include arXiv preprints in Table 1

## Data Sources

This skill checks multiple sources **in priority order**. All are optional — if a source is not configured or not requested, skip it silently.

### Source Selection

Parse `$ARGUMENTS` for a `— sources:` directive:
- **If `— sources:` is specified**: Only search the listed sources (comma-separated). Valid values: `zotero`, `obsidian`, `local`, `web`, `all`.
- **If not specified**: Default to `all` — search every available source in priority order.

Examples:
```
/research-lit-top "diffusion models"                        → all (default)
/research-lit-top "diffusion models" — sources: all         → all
/research-lit-top "diffusion models" — sources: zotero      → Zotero only
/research-lit-top "diffusion models" — sources: zotero, web → Zotero + web
/research-lit-top "diffusion models" — sources: local       → local PDFs only
/research-lit-top "topic" — sources: obsidian, local, web   → skip Zotero
```

### Source Table

| Priority | Source | ID | How to detect | What it provides |
|----------|--------|----|---------------|-----------------|
| 1 | **Zotero** (via MCP) | `zotero` | Try calling any `mcp__zotero__*` tool — if unavailable, skip | Collections, tags, annotations, PDF highlights, BibTeX, semantic search |
| 2 | **Obsidian** (via MCP) | `obsidian` | Try calling any `mcp__obsidian-vault__*` tool — if unavailable, skip | Research notes, paper summaries, tagged references, wikilinks |
| 3 | **Local PDFs** | `local` | `Glob: papers/**/*.pdf, literature/**/*.pdf` | Raw PDF content (first 3 pages) |
| 4 | **Web search** | `web` | Always available (WebSearch) | arXiv, Semantic Scholar, Google Scholar |

> **Graceful degradation**: If no MCP servers are configured, the skill works exactly as before (local PDFs + web search). Zotero and Obsidian are pure additions.

## Workflow

### Step 0a: Search Zotero Library (if available)

**Skip this step entirely if Zotero MCP is not configured.**

Try calling a Zotero MCP tool (e.g., search). If it succeeds:

1. **Search by topic**: Use the Zotero search tool to find papers matching the research topic
2. **Read collections**: Check if the user has a relevant collection/folder for this topic
3. **Extract annotations**: For highly relevant papers, pull PDF highlights and notes — these represent what the user found important
4. **Export BibTeX**: Get citation data for relevant papers (useful for `/paper-write` later)
5. **Compile results**: For each relevant Zotero entry, extract:
   - Title, authors, year, venue
   - User's annotations/highlights (if any)
   - Tags the user assigned
   - Which collection it belongs to

> Zotero annotations are gold — they show what the user personally highlighted as important, which is far more valuable than generic summaries.

### Step 0b: Search Obsidian Vault (if available)

**Skip this step entirely if Obsidian MCP is not configured.**

Try calling an Obsidian MCP tool (e.g., search). If it succeeds:

1. **Search vault**: Search for notes related to the research topic
2. **Check tags**: Look for notes tagged with relevant topics (e.g., `#diffusion-models`, `#paper-review`)
3. **Read research notes**: For relevant notes, extract the user's own summaries and insights
4. **Follow links**: If notes link to other relevant notes (wikilinks), follow them for additional context
5. **Compile results**: For each relevant note:
   - Note title and path
   - User's summary/insights
   - Links to other notes (research graph)
   - Any frontmatter metadata (paper URL, status, rating)

> Obsidian notes represent the user's **processed understanding** — more valuable than raw paper content for understanding their perspective.

### Step 0c: Scan Local Paper Library

Before searching online, check if the user already has relevant papers locally:

1. **Locate library**: Check PAPER_LIBRARY paths for PDF files
   ```
   Glob: papers/**/*.pdf, literature/**/*.pdf
   ```

2. **De-duplicate against Zotero**: If Step 0a found papers, skip any local PDFs already covered by Zotero results (match by filename or title).

3. **Filter by relevance**: Match filenames and first-page content against the research topic. Skip clearly unrelated papers.

4. **Summarize relevant papers**: For each relevant local PDF (up to MAX_LOCAL_PAPERS):
   - Read first 3 pages (title, abstract, intro)
   - Extract: title, authors, year, core contribution, relevance to topic
   - Flag papers that are directly related vs tangentially related

5. **Build local knowledge base**: Compile summaries into a "papers you already have" section. This becomes the starting point — external search fills the gaps.

> If no local papers are found, skip to Step 1. If the user has a comprehensive local collection, the external search can be more targeted (focus on what's missing).

### Step 1: Search (external)
- Use WebSearch to find recent papers on the topic
- Check arXiv, Semantic Scholar, Google Scholar
- Focus on papers from last 2 years unless studying foundational work
- **De-duplicate**: Skip papers already found in Zotero, Obsidian, or local library

**arXiv API search** (always runs, no download by default):

Locate the fetch script and search arXiv directly:
```bash
# Try to find arxiv_fetch.py
SCRIPT=$(find tools/ -name "arxiv_fetch.py" 2>/dev/null | head -1)
# If not found, check ARIS install
[ -z "$SCRIPT" ] && SCRIPT=$(find ~/.claude/skills/arxiv/ -name "arxiv_fetch.py" 2>/dev/null | head -1)

# Search arXiv API for structured results (title, abstract, authors, categories)
python3 "$SCRIPT" search "QUERY" --max 10
```

If `arxiv_fetch.py` is not found, fall back to WebSearch for arXiv (same as before).

The arXiv API returns structured metadata (title, abstract, full author list, categories, dates) — richer than WebSearch snippets. Merge these results with WebSearch findings and de-duplicate.

**Optional PDF download** (only when `ARXIV_DOWNLOAD = true`):

After all sources are searched and papers are ranked by relevance:
```bash
# Download top N most relevant arXiv papers
python3 "$SCRIPT" download ARXIV_ID --dir papers/
```
- Only download papers ranked in the top ARXIV_MAX_DOWNLOAD by relevance
- Skip papers already in the local library
- 1-second delay between downloads (rate limiting)
- Verify each PDF > 10 KB

### Step 2: Analyze Each Paper
For each relevant paper (from all sources), extract:
- **Problem**: What gap does it address?
- **Method**: Core technical contribution (1-2 sentences)
- **Results**: Key numbers/claims
- **Relevance**: How does it relate to our work?
- **Source**: Where we found it (Zotero/Obsidian/local/web) — helps user know what they already have vs what's new

### Step 2b: Venue Classification (Top-Venue Filtering)

For **every paper** collected from all sources, classify its publication venue:

1. **Extract venue info**: From Zotero metadata, Semantic Scholar, arXiv, or paper content — identify where the paper was published (conference name, journal name, or preprint server).

2. **Classify using your own knowledge**: Based on your knowledge of the research field, determine whether the venue qualifies as a top-tier venue. Use the following criteria:
   - **Top-Venue**: The paper is published at a venue widely recognized as top-tier in its field (equivalent to CCF-A level). Examples include but are not limited to: NeurIPS, ICML, ICLR, CVPR, ICCV, ECCV, ACL, EMNLP, AAAI, IJCAI, SIGIR, KDD, WWW, SIGMOD, VLDB, OSDI, SOSP, STOC, FOCS, Nature, Science, TPAMI, IJCV, JMLR, etc. **Do NOT hardcode a fixed list** — use your understanding of the specific research field to judge. A venue that is top-tier in one field may not be in another.
   - **Preprint**: The paper is only available on arXiv or similar preprint servers and has not been published at a peer-reviewed venue yet.
   - **Non-Top Venue**: Published at a peer-reviewed venue that is not considered top-tier for this specific field.

3. **Resolve arXiv papers**: Many arXiv papers have actually been accepted at top venues. For each arXiv paper:
   - Check the `comments` field in arXiv metadata (often says "Accepted at NeurIPS 2025" etc.)
   - Search Semantic Scholar or DBLP for the paper title to find the actual publication venue
   - If confirmed at a top venue, classify as **Top-Venue** (not Preprint)

4. **Handle INCLUDE_PREPRINTS flag**: If `— include-preprints: true` is set:
   - Include high-quality preprints (highly cited, from reputable groups) in Table 1 alongside top-venue papers
   - Mark them with a "(Preprint)" tag in the Venue column

5. **Assign labels**: Each paper gets one of:
   - `Top-Venue` — published at a top-tier conference/journal
   - `Preprint` — arXiv/preprint only, not yet peer-reviewed at a top venue
   - `Non-Top` — published but not at a top-tier venue

### Step 3: Synthesize
- Group papers by approach/theme
- Identify consensus vs disagreements in the field
- Find gaps that our work could fill
- If Obsidian notes exist, incorporate the user's own insights into the synthesis
- **Highlight** which themes are dominated by top-venue work and where gaps exist

### Step 4: Output — Dual Table Format

Present results in **two separate tables**, split by venue classification:

---

**Table 1: Top-Venue Papers**

Papers published at top-tier conferences and journals in this field:

```
| # | Paper | Venue | Year | Method | Key Result | Relevance | Source |
|---|-------|-------|------|--------|------------|-----------|--------|
```

- `Paper`: "First Author et al." with link if available
- `Venue`: Specific venue name (e.g., "NeurIPS", "CVPR", "TPAMI")
- `Year`: Publication year
- `Method`: Core technical approach (1-2 sentences)
- `Key Result`: Main quantitative or qualitative finding
- `Relevance`: How it relates to the research topic (High/Medium/Low + brief note)
- `Source`: Where found (Zotero/Obsidian/Local/Web)

If `INCLUDE_PREPRINTS = true`, high-quality preprints appear here with Venue shown as "arXiv (Preprint)".

---

**Table 2: Other Notable Work**

Relevant preprints and papers from non-top venues that are still worth noting:

```
| # | Paper | Status | Year | Method | Key Result | Relevance | Source |
|---|-------|--------|------|--------|------------|-----------|--------|
```

- `Status`: Either "Preprint" or the actual non-top venue name
- All other columns same as Table 1

---

**After the tables**, provide:
1. **Summary statistics**: "Found X top-venue papers, Y preprints, Z from other venues"
2. **Narrative synthesis** (3-5 paragraphs): landscape overview, grouped by theme, emphasizing top-venue consensus
3. **Gap analysis**: What's missing from top-venue coverage? Where might there be opportunities?

If Zotero BibTeX was exported, include a `references.bib` snippet for direct use in paper writing.

### Step 5: Save (if requested)
- Save paper PDFs to `literature/` or `papers/`
- Update related work notes in project memory
- If Obsidian is available, optionally create a literature review note in the vault

## Key Rules
- Always include paper citations (authors, year, venue)
- Distinguish between peer-reviewed and preprints
- Be honest about limitations of each paper
- Note if a paper directly competes with or supports our approach
- **Never fail because a MCP server is not configured** — always fall back gracefully to the next data source
- Zotero/Obsidian tools may have different names depending on how the user configured the MCP server (e.g., `mcp__zotero__search` or `mcp__zotero-mcp__search_items`). Try the most common patterns and adapt.
- **Do NOT hardcode a venue list** — rely on your knowledge of the field to judge venue quality. Different fields have different top venues.
- **Always verify arXiv papers** — check if they have been accepted at a venue before classifying as Preprint.
- **Be transparent about uncertainty** — if you're unsure whether a venue qualifies as top-tier for the specific field, note the uncertainty in the table.
