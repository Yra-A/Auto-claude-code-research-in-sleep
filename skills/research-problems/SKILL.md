---
name: research-problems
description: Discover open problems, limitations, and challenges in a research field from authoritative sources (top venues, classic books, renowned authors). Use when user says "找问题", "find problems", "open problems", "limitations", "challenges in", "research gaps", "what's unsolved", "领域瓶颈", "研究瓶颈", "有什么问题没解决", or wants to understand the frontier limitations and open questions in a field.
argument-hint: [research-field-or-topic] — depth: survey | focused — sources: venues, books, authors
allowed-tools: Bash(*), Read, Glob, Grep, WebSearch, WebFetch, Write, Agent, mcp__zotero__*, mcp__obsidian-vault__*, mcp__codex__codex
---

# Research Problems & Limitations Discovery

Discover open problems, limitations, and frontier challenges in: **$ARGUMENTS**

## Purpose

Unlike `/research-lit` (which surveys methods) or `/idea-creator` (which generates ideas), this skill performs a **problem-centric** literature analysis. It systematically extracts:

1. **Open Problems** — explicitly stated unsolved questions
2. **Limitations** — known weaknesses of current methods
3. **Challenges** — structural difficulties that block progress
4. **Assumptions Under Scrutiny** — widely-held beliefs that are questioned or unverified

All extracted problems are traced back to **authoritative sources only**: top-tier venues, classic textbooks/monographs, and publications from renowned researchers in the field.

## Constants

- **PAPER_LIBRARY** — Local directory containing user's paper collection (PDFs). Check these paths in order:
  1. `papers/` in the current project directory
  2. `literature/` in the current project directory
  3. Custom path specified by user in `CLAUDE.md` under `## Paper Library`
- **MAX_LOCAL_PAPERS = 20** — Maximum number of local PDFs to scan (read first 3 pages each).
- **ARXIV_DOWNLOAD = false** — When `true`, download top relevant arXiv PDFs to PAPER_LIBRARY.
- **ARXIV_MAX_DOWNLOAD = 5** — Maximum number of PDFs to download when `ARXIV_DOWNLOAD = true`.
- **DEPTH = survey** — `survey`: broad scan across sub-areas (default). `focused`: deep dive into a narrow sub-problem.
- **TIME_HORIZON = 3** — How many years back to search for problems (default: 3 years). Foundational problems from classic works are always included regardless.
- **REVIEWER_MODEL = `gpt-5.4`** — Model used via Codex MCP for cross-verification and synthesis.
- **INCLUDE_PREPRINTS = false** — When `true`, include problems identified in high-quality arXiv preprints from top research groups.

> 💡 Overrides:
> - `/research-problems "topic" — depth: focused` — narrow deep-dive mode
> - `/research-problems "topic" — depth: survey` — broad scan (default)
> - `/research-problems "topic" — time horizon: 5` — look back 5 years
> - `/research-problems "topic" — include-preprints: true` — include top-group preprints
> - `/research-problems "topic" — paper library: ~/my_papers/` — custom local PDF path
> - `/research-problems "topic" — sources: zotero, web` — selective sources
> - `/research-problems "topic" — arxiv download: true` — download relevant PDFs

## Source Authority Criteria

This skill is **source-strict**. A problem or limitation is only included in the primary output if it comes from at least one of the following authoritative source types:

### Tier 1: Top-Venue Publications
Papers published at venues widely recognized as top-tier in the relevant field. Use your knowledge of the field to judge — examples include but are not limited to:
- **ML/AI**: NeurIPS, ICML, ICLR, AAAI, IJCAI, JMLR, TPAMI, etc.
- **CV**: CVPR, ICCV, ECCV, IJCV, etc.
- **NLP**: ACL, EMNLP, NAACL, TACL, CL, etc.
- **Systems**: OSDI, SOSP, EuroSys, ATC, etc.
- **Data**: KDD, SIGMOD, VLDB, ICDE, SIGIR, WWW, etc.
- **Robotics**: RSS, CoRL, ICRA, IROS, T-RO, RA-L, etc.
- **Theory**: STOC, FOCS, SODA, COLT, etc.
- **General Science**: Nature, Science, PNAS, etc.

**Do NOT hardcode a fixed list** — adapt to the specific field. A top venue in robotics differs from one in NLP.

### Tier 2: Classic Books & Monographs
Widely-cited textbooks, monographs, and foundational surveys that define a field:
- e.g., Goodfellow et al. "Deep Learning", Bishop "Pattern Recognition and Machine Learning", Sutton & Barto "Reinforcement Learning", Russell & Norvig "AIMA"
- Landmark survey papers with 500+ citations that comprehensively map a field
- PhD theses from top labs that identify open problems in their conclusion chapters

### Tier 3: Renowned Authors
Papers from researchers recognized as leaders or pioneers in the specific field:
- Turing Award / Fields Medal / Abel Prize winners working in the area
- First/last authors with sustained high-impact publication records at top venues
- Founding authors of key methods or frameworks in the area
- **Identify renowned authors dynamically** based on citation patterns and venue history — do NOT rely on a fixed list of names

### Preprint Exception
When `INCLUDE_PREPRINTS = true`, also consider:
- arXiv preprints from authors who satisfy Tier 3 criteria
- Preprints from top research labs (Google DeepMind, OpenAI, Meta FAIR, Microsoft Research, etc.)
- Mark these clearly as "(Preprint)" in the output

> **Source verification**: For every problem extracted, you MUST record which paper/book it came from and verify the source meets at least one Tier criterion. Problems from unverifiable or non-authoritative sources go to a separate "Supplementary" section.

## Data Sources

This skill checks multiple data sources **in priority order**. All are optional — skip silently if unavailable.

### Source Selection

Parse `$ARGUMENTS` for a `— sources:` directive:
- **If specified**: Only search listed sources. Valid values: `zotero`, `obsidian`, `local`, `web`, `all`.
- **If not specified**: Default to `all`.

### Source Table

| Priority | Source | ID | How to detect | What it provides |
|----------|--------|----|---------------|-----------------|
| 1 | **Zotero** (via MCP) | `zotero` | Try calling any `mcp__zotero__*` tool | Papers + annotations (user's highlights of problems are gold) |
| 2 | **Obsidian** (via MCP) | `obsidian` | Try calling any `mcp__obsidian-vault__*` tool | User's own notes on open problems |
| 3 | **Local PDFs** | `local` | `Glob: papers/**/*.pdf, literature/**/*.pdf` | Raw PDF content |
| 4 | **Web search** | `web` | Always available | arXiv, Semantic Scholar, Google Scholar |

> **Graceful degradation**: If no MCP servers are configured, the skill works with local PDFs + web search only.

## Workflow

### Step 1: Scope & Decompose the Field

Before searching, break the research field into sub-areas to ensure comprehensive coverage:

1. **Parse the user's topic**: Identify the core field and any constraints (e.g., "sample efficiency in offline RL" → field=RL, sub-area=offline, focus=sample efficiency)
2. **Decompose into 3-7 sub-areas**: Based on your knowledge of the field, identify the major sub-areas where open problems may exist:
   - Theoretical foundations
   - Methodology / algorithmic challenges
   - Scalability / computational challenges
   - Data / benchmark limitations
   - Evaluation / metrics challenges
   - Real-world deployment gaps
   - Cross-disciplinary connections
3. **If DEPTH = survey**: Cover all sub-areas broadly (2-3 problems each)
4. **If DEPTH = focused**: Focus on 1-2 sub-areas most relevant to the user's topic (5-10 problems each)

> If the user's topic is too broad (e.g., "machine learning", "AI"), **STOP and ask them to narrow it**. A good topic is 1-2 sentences specifying a sub-field, e.g., "limitations of current diffusion models for video generation" or "open problems in multi-agent reinforcement learning".

### Step 2: Search Authoritative Sources

#### Step 2a: Search Zotero (if available)

**Skip if Zotero MCP not configured.**

1. Search for papers in the field
2. **Prioritize annotations**: User highlights and notes about "limitations", "future work", "open problem", "challenge" are extremely valuable
3. Extract venue info for authority verification

#### Step 2b: Search Obsidian (if available)

**Skip if Obsidian MCP not configured.**

1. Search for notes tagged with the research topic
2. Look for notes about problems, limitations, or open questions the user has previously identified

#### Step 2c: Scan Local Paper Library

1. Locate library: `Glob: papers/**/*.pdf, literature/**/*.pdf`
2. De-duplicate against Zotero results
3. For relevant PDFs, read:
   - **Abstract** — often states the problem being addressed (which implies a prior limitation)
   - **Introduction, Section 1-2** — usually contains "Despite progress in X, challenges remain in Y"
   - **Related Work / Discussion** — comparative limitations
   - **Conclusion / Future Work** — explicitly stated open problems
   - **Limitation sections** — some venues (NeurIPS, ICML) require explicit limitation sections

#### Step 2d: Web Search — Survey & Position Papers (HIGH PRIORITY)

Survey papers and position papers are the richest sources of open problems. Search specifically for these:

```
WebSearch: "[topic] survey open problems"
WebSearch: "[topic] challenges survey [current year]"
WebSearch: "[topic] position paper future directions"
WebSearch: "[topic] limitations current methods"
WebSearch: "[topic] benchmark challenges"
```

For each result:
1. Verify the venue meets Tier 1/2/3 criteria
2. If it does, use WebFetch to read the abstract and relevant sections
3. Extract every stated problem, limitation, or challenge

#### Step 2e: Web Search — Recent Top-Venue Papers

Search for recent papers at top venues that discuss limitations:

```
WebSearch: "[topic] NeurIPS/ICML/ICLR [year] limitations"
WebSearch: "[topic] [top-venue-for-field] challenges"
WebSearch: "open problems [topic] [year]"
```

Also search for:
- **Best Paper Award winners** in the field — they often define new problem directions
- **Invited talks / keynotes** at top venues — renowned researchers often outline open problems
- **Workshop reports** from top venues — workshops are created around open problems

#### Step 2f: Web Search — Classic & Foundational Sources

Search for problems that have been known for longer but remain unsolved:

```
WebSearch: "[topic] textbook open problems"
WebSearch: "[topic] [famous-author] challenges"
WebSearch: "[topic] fundamental limitations"
WebSearch: "[topic] impossibility results"
WebSearch: "[topic] theoretical barriers"
```

#### Step 2g: arXiv API Search

```bash
SCRIPT=$(find tools/ -name "arxiv_fetch.py" 2>/dev/null | head -1)
[ -z "$SCRIPT" ] && SCRIPT=$(find ~/.claude/skills/arxiv/ -name "arxiv_fetch.py" 2>/dev/null | head -1)

python3 "$SCRIPT" search "[topic] survey challenges limitations" --max 15
```

If `arxiv_fetch.py` not found, fall back to WebSearch.

For each arXiv result:
1. Check `comments` field for venue acceptance
2. Verify author authority (Tier 3 check)
3. If authoritative, read abstract for problem statements

### Step 3: Extract & Classify Problems

For **every authoritative paper/book** found, extract problems using these extraction patterns:

#### Extraction Signals (what to look for in text)

- **Explicit markers**: "open problem", "unsolved", "remains a challenge", "future work", "limitation", "shortcoming", "gap", "bottleneck", "barrier", "despite progress", "it is unclear whether", "no existing method can", "fails when", "breaks down in"
- **Comparative limitations**: "Method A outperforms B but cannot handle C"
- **Assumptions**: "We assume X, relaxing this is left for future work"
- **Negative results**: "We show that approach X cannot achieve Y" (impossibility / lower bounds)
- **Benchmark saturation**: "All methods achieve >95% on benchmark Z, but real-world performance remains poor"

#### Problem Classification

Classify each extracted problem into one of these categories:

| Category | Description | Example |
|----------|-------------|---------|
| **Open Problem** | Explicitly stated unsolved question | "Can transformers learn compositional generalization?" |
| **Methodological Limitation** | A known weakness of current SOTA methods | "Diffusion models require 1000 denoising steps" |
| **Scalability Challenge** | Problems that arise at scale | "RLHF does not scale beyond single-turn" |
| **Evaluation Gap** | Metrics/benchmarks that are inadequate | "Perplexity does not correlate with factual accuracy" |
| **Theoretical Gap** | Missing theoretical understanding | "No convergence guarantees for Adam in non-convex settings" |
| **Data/Resource Limitation** | Data scarcity, annotation cost, compute barriers | "No large-scale multilingual reasoning benchmark" |
| **Deployment Challenge** | Gap between research and real-world use | "LLM hallucination rates unacceptable for medical use" |
| **Assumption Under Scrutiny** | Widely-held beliefs being questioned | "Is scaling alone sufficient for reasoning?" |

### Step 4: Cross-Verify with External LLM (Optional but Recommended)

If Codex MCP is available, call REVIEWER_MODEL for cross-verification:

```
mcp__codex__codex:
  config: {"model_reasoning_effort": "xhigh"}
  prompt: |
    You are a senior researcher surveying open problems in [field].

    I've compiled the following problems and limitations from the literature:
    [paste extracted problems with sources]

    Please:
    1. Verify: Are these accurately stated? Any misinterpretations?
    2. Rank: Which are the most impactful / most likely to yield publishable work?
    3. Add: Are there major open problems I'm missing? (Only cite specific papers/books)
    4. Connect: Which problems are related or could be addressed together?
    5. Trend: Which problems are becoming MORE important vs being gradually solved?
```

Merge the LLM's additions into the report, but **only if it provides specific source citations that you can verify**.

### Step 5: Synthesize & Rank

1. **De-duplicate**: Merge problems that are essentially the same stated differently
2. **Cross-reference**: Note when the same problem is mentioned by multiple authoritative sources (stronger signal)
3. **Rank by research opportunity**: Consider:
   - How many authoritative sources mention it? (consensus = important)
   - Is progress being made, or is it truly stuck? (stuck = harder but higher impact)
   - Could addressing it lead to a publishable contribution? (actionability)
   - Is there a clear evaluation setup for progress? (measurability)
4. **Identify problem clusters**: Group related problems that might be addressed together

### Step 6: Output — Problem Landscape Report

Write the report to `PROBLEM_LANDSCAPE.md` in the project root:

```markdown
# Problem Landscape: [Field/Topic]

**Generated**: [date]
**Depth**: survey | focused
**Sources analyzed**: X top-venue papers, Y books/surveys, Z from renowned authors
**Problems identified**: N total (after de-duplication)

---

## Field Decomposition

| Sub-area | # Problems | Maturity | Trend |
|----------|-----------|----------|-------|
| [sub-area 1] | N | Active / Stalled / Emerging | 🔺 Growing / 🔻 Shrinking / ➡️ Stable |
| ... | | | |

---

## 🔴 High-Impact Open Problems

Problems with broad consensus from multiple authoritative sources, high potential for publishable work.

### Problem 1: [concise title]
- **Category**: [Open Problem / Methodological Limitation / ...]
- **Statement**: [1-3 sentence precise formulation]
- **Why it matters**: [impact if solved]
- **Current status**: [what has been tried and why it failed/is insufficient]
- **Authoritative sources**:
  - [Author et al., Venue Year] — "[exact quote or close paraphrase]"
  - [Author et al., Venue Year] — "[exact quote or close paraphrase]"
  - [Book Title, Chapter X] — "[relevant passage]"
- **Source authority**: Tier 1 (top-venue) + Tier 3 (renowned author: [name])
- **Actionability**: HIGH / MEDIUM / LOW — [brief reason]
- **Related problems**: [links to other problems in this report]

### Problem 2: [concise title]
...

---

## 🟡 Emerging Challenges

Recently identified problems, fewer sources but high potential significance.

### Problem N: [concise title]
[same structure as above]

---

## 🟢 Known Limitations (Partially Addressed)

Limitations where progress is being made but the problem isn't fully solved.

### Problem M: [concise title]
[same structure as above, plus: "Recent progress: [paper] achieved X but Y remains"]

---

## 📚 Foundational / Long-Standing Problems

Classic open problems from textbooks and foundational papers.

### Problem K: [concise title]
[same structure as above]

---

## Supplementary: Problems from Non-Authoritative Sources

Problems found in non-top venues or unverified preprints. Included for completeness but NOT verified against authority criteria.

| # | Problem | Source | Why included |
|---|---------|--------|-------------|
| 1 | ... | arXiv preprint (no venue) | Interesting but unverified |

---

## Problem Connectivity Map

Which problems are related and could be addressed together:

```
Problem 1 ←→ Problem 3: Both stem from [shared root cause]
Problem 2 → Problem 5: Solving 2 would enable progress on 5
Problem 4 ⊂ Problem 7: 4 is a special case of 7
```

---

## Source Authority Summary

| Source Type | Count | Examples |
|-------------|-------|---------|
| Top-Venue Papers | X | NeurIPS 2025, ICML 2024, ... |
| Survey Papers | Y | [Author] et al. survey, ... |
| Books/Monographs | Z | [Book Title], ... |
| Renowned Authors | W | [Name] (Turing Award), [Name] (h-index >100), ... |
| Preprints (if included) | P | [Lab/Group] preprints |

---

## Recommended Next Steps

1. **For idea generation**: Run `/idea-creator` targeting Problem [X] — highest actionability
2. **For deeper dive**: Run `/research-problems "[specific sub-problem]" — depth: focused`
3. **For literature review**: Run `/research-lit-top "[problem area]"` to find methods addressing Problem [X]
```

### Step 7: Save

1. Write the report to `PROBLEM_LANDSCAPE.md`
2. If Obsidian is available, optionally create a note in the vault
3. If the user has a `CLAUDE.md`, note the key findings there

## Key Rules

- **Authority is non-negotiable**: Never include a problem in the main tables unless it has at least one Tier 1/2/3 source. This is the core differentiator of this skill.
- **Quote or closely paraphrase**: For each problem, include the actual language used by the source. "Future work: we leave X for future investigation" is more trustworthy than a summary.
- **Verify arXiv papers**: Many arXiv papers are accepted at top venues — check `comments` field and DBLP/Semantic Scholar before classifying as preprint.
- **Do NOT hardcode venue or author lists**: Use your knowledge of the field to judge authority dynamically.
- **Be transparent about uncertainty**: If you're unsure whether a source meets authority criteria, say so.
- **Distinguish problem types clearly**: An "open problem" (nobody knows how) is very different from a "limitation" (known weakness of a specific method).
- **Recency matters but isn't everything**: A problem from a 2020 textbook that's still unsolved is more important than a minor limitation from a 2025 paper.
- **Never fail because a MCP server is not configured** — always fall back gracefully.
- **Large file handling**: If the Write tool fails due to file size, immediately retry using Bash (`cat << 'EOF' > file`). Do NOT ask permission.
- Zotero/Obsidian tools may have different names depending on configuration. Try common patterns and adapt.

## Composing with Other Skills

This skill feeds directly into the idea generation pipeline:

```
/research-problems "field"         → problem landscape (this skill)
/research-lit-top "specific problem" → deep literature on a specific problem
/idea-creator "solve problem X"    → generate ideas targeting a specific problem
/novelty-check "proposed solution" → verify the solution is novel
/research-review "idea + evidence" → critical feedback from external LLM
```

The `/idea-discovery` pipeline can also be started from this skill's output:
```
/research-problems → pick top problem → /idea-discovery "solutions for [problem]"
```
