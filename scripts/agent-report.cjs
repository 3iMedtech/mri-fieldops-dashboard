#!/usr/bin/env node
/**
 * FieldOps3i — Agent Utilization & Performance Report
 *
 * Usage:
 *   node scripts/agent-report.cjs              # print report to stdout
 *   node scripts/agent-report.cjs --json       # raw JSON metrics
 *   node scripts/agent-report.cjs --md         # write SUMMARY.md
 *
 * Input:  automation/agent-analytics/invocations.jsonl
 * Output: console (default), or writes automation/agent-analytics/SUMMARY.md (--md)
 */

const fs   = require('fs');
const path = require('path');

// ── Config ─────────────────────────────────────────────────────────────────
const ROOT          = path.resolve(__dirname, '..');
const LOG_FILE      = path.join(ROOT, 'automation/agent-analytics/invocations.jsonl');
const REGISTRY_FILE = path.join(ROOT, 'automation/agent-analytics/REGISTRY.md');
const SUMMARY_FILE  = path.join(ROOT, 'automation/agent-analytics/SUMMARY.md');

const HOT_DAYS      = 14;    // used within N days → HOT
const ACTIVE_DAYS   = 30;    // used within N days → ACTIVE (else STALE)
const HOT_MIN_USES  = 3;     // min lifetime uses to qualify as HOT

// All agents defined in the project (slug → metadata).
// Update this list when adding or removing agent definition files.
const DEFINED_AGENTS = {
  // Tier 0
  'fieldops-delivery-orchestrator':       { tier: 0, track: 'Cross',   label: 'Delivery Orchestrator' },
  // Tier 1
  'fieldops-database-pm':                 { tier: 1, track: 'DB',      label: 'Database PM' },
  'fieldops-runtime-pm':                  { tier: 1, track: 'Runtime', label: 'Runtime PM' },
  'fieldops-release-pm':                  { tier: 1, track: 'Release', label: 'Release PM' },
  // Tier 2
  'fieldops-code-reviewer':               { tier: 2, track: 'Cross',   label: 'Code Reviewer',            isReviewer: true },
  'fieldops-sql-rls-safety-agent':        { tier: 2, track: 'DB',      label: 'SQL/RLS Safety',           isReviewer: true },
  'fieldops-migration-runbook-verifier':  { tier: 2, track: 'DB',      label: 'Runbook Verifier',         isReviewer: true },
  'fieldops-data-reconciliation-agent':   { tier: 2, track: 'DB',      label: 'Data Reconciliation' },
  'fieldops-runtime-integration-agent':   { tier: 2, track: 'Runtime', label: 'Runtime Integration' },
  'fieldops-qa-test-automation-agent':    { tier: 2, track: 'Runtime', label: 'QA Test Automation' },
  'fieldops-automation-memory-agent':     { tier: 2, track: 'Cross',   label: 'Automation Memory' },
  // Tier 3
  'fieldops-orchestrator':                { tier: 3, track: 'Cross',   label: 'Module Orchestrator' },
  'fieldops-observability-agent':         { tier: 3, track: 'Release', label: 'Observability' },
  'fieldops-bug-agent':                   { tier: 3, track: 'Cross',   label: 'Bug Agent' },
  'fieldops-ui-agent':                    { tier: 3, track: 'Runtime', label: 'UI Agent' },
  'fieldops-supabase-agent':              { tier: 3, track: 'DB',      label: 'Supabase Agent' },
  'fieldops-test-agent':                  { tier: 3, track: 'Release', label: 'Manual Test Agent' },
  'fieldops-release-agent':              { tier: 3, track: 'Release', label: 'Release Agent' },
  // Tier 4
  'fieldops-product-design-lead':         { tier: 4, track: 'Design',  label: 'Product Design Lead' },
  'fieldops-enterprise-ux-researcher':    { tier: 4, track: 'Design',  label: 'UX Researcher' },
  'fieldops-dashboard-usability-auditor': { tier: 4, track: 'Design',  label: 'Usability Auditor' },
  'fieldops-design-system-guardian':      { tier: 4, track: 'Design',  label: 'Design System Guardian' },
  'fieldops-accessibility-reviewer':      { tier: 4, track: 'Design',  label: 'Accessibility Reviewer' },
  'fieldops-microinteraction-designer':   { tier: 4, track: 'Design',  label: 'Microinteraction Designer' },
};

// ── Load & parse log ────────────────────────────────────────────────────────
function loadLog() {
  if (!fs.existsSync(LOG_FILE)) return [];
  return fs.readFileSync(LOG_FILE, 'utf8')
    .split('\n')
    .filter(l => l.trim())
    .map((l, i) => {
      try { return JSON.parse(l); }
      catch(e) { console.error(`Line ${i+1} parse error: ${e.message}`); return null; }
    })
    .filter(Boolean);
}

// ── Compute metrics ─────────────────────────────────────────────────────────
function compute(log) {
  const now        = new Date();
  const sessions   = new Set(log.map(e => e.session));
  const categories = {};
  const agentStats = {};

  // Init all defined agents
  for (const [slug, meta] of Object.entries(DEFINED_AGENTS)) {
    agentStats[slug] = {
      ...meta, slug,
      invocations: 0,
      passes: 0, stops: 0, escalates: 0, holds: 0, skipped: 0, na: 0,
      caught: 0,         // findings acted upon
      lastUsed: null,
      sessions: new Set(),
      categories: {},
      recentCommits: [],
    };
  }

  // Aggregate log entries
  for (const e of log) {
    const slug = e.agent;
    if (!agentStats[slug]) {
      // Unknown agent — create ad-hoc entry
      agentStats[slug] = {
        tier: '?', track: '?', label: slug, isReviewer: false, slug,
        invocations: 0, passes: 0, stops: 0, escalates: 0, holds: 0, skipped: 0, na: 0,
        caught: 0, lastUsed: null, sessions: new Set(), categories: {}, recentCommits: [],
      };
    }
    const s = agentStats[slug];
    s.invocations++;
    if (e.verdict === 'PASS')     s.passes++;
    if (e.verdict === 'STOP')     s.stops++;
    if (e.verdict === 'ESCALATE') s.escalates++;
    if (e.verdict === 'HOLD')     s.holds++;
    if (e.verdict === 'SKIPPED')  s.skipped++;
    if (e.verdict === 'N/A')      s.na++;
    if (e.caught)                 s.caught++;
    if (e.session) s.sessions.add(e.session);
    if (e.ts) {
      const d = new Date(e.ts);
      if (!s.lastUsed || d > s.lastUsed) s.lastUsed = d;
    }
    if (e.category) s.categories[e.category] = (s.categories[e.category] || 0) + 1;
    if (e.category) categories[e.category]   = (categories[e.category] || 0) + 1;
    if (e.commit && e.commit !== 'null') s.recentCommits.push(e.commit);
  }

  // Compute derived fields
  for (const s of Object.values(agentStats)) {
    s.sessions = s.sessions.size;
    // Health
    const daysSince = s.lastUsed ? Math.round((now - s.lastUsed) / 86400000) : Infinity;
    if (s.invocations === 0)                                     s.health = 'DEAD';
    else if (daysSince <= HOT_DAYS && s.invocations >= HOT_MIN_USES) s.health = 'HOT';
    else if (daysSince <= ACTIVE_DAYS)                               s.health = 'ACTIVE';
    else                                                              s.health = 'STALE';
    s.daysSince = daysSince === Infinity ? null : daysSince;
    // Catch rate (review agents: STOP+ESCALATE / total non-N/A)
    const reviewable = s.invocations - s.na - s.skipped;
    s.catchRate = reviewable > 0 ? ((s.stops + s.escalates) / reviewable * 100).toFixed(0) + '%' : '—';
    // Value rate: how often a catch was acted upon vs total invocations
    s.valueRate = s.invocations > 0 ? (s.caught / s.invocations * 100).toFixed(0) + '%' : '—';
    // Last used formatted
    s.lastUsedStr = s.lastUsed ? s.lastUsed.toISOString().slice(0, 10) : '—';
    // Top category
    const cats = Object.entries(s.categories).sort((a,b)=>b[1]-a[1]);
    s.topCategory = cats.length ? cats[0][0] : '—';
    // Recent commits (deduplicated, last 3)
    s.recentCommits = [...new Set(s.recentCommits)].slice(-3);
  }

  return { agentStats, sessions: sessions.size, totalInvocations: log.length, categories };
}

// ── Recommendations engine ──────────────────────────────────────────────────
function recommend(agentStats) {
  const recs = [];

  for (const s of Object.values(agentStats)) {
    if (s.health === 'DEAD' && s.tier <= 2) {
      recs.push({ type: 'REMOVE', agent: s.slug, reason: `Tier ${s.tier} specialist — never used. Definition adds maintenance weight with zero ROI.` });
    } else if (s.health === 'DEAD' && s.tier === 3) {
      recs.push({ type: 'REMOVE', agent: s.slug, reason: 'Legacy module agent — never used. Superseded by Tier 2 specialists or direct operator work.' });
    } else if (s.health === 'DEAD' && s.tier === 4) {
      recs.push({ type: 'REMOVE', agent: s.slug, reason: 'Design advisory — never used. Consolidate the 6 design advisors to 1 entry point when needed.' });
    } else if (s.health === 'STALE' && s.invocations < 3) {
      recs.push({ type: 'REVIEW', agent: s.slug, reason: `Only ${s.invocations} use(s). Either embed into CLAUDE.md routing rules to trigger it more, or retire it.` });
    } else if (s.isReviewer && s.invocations >= 5 && parseInt(s.catchRate) === 0) {
      recs.push({ type: 'EDIT', agent: s.slug, reason: 'Review agent with 0% catch rate — checklist may be too generic or tasks routed around it. Sharpen the checklist.' });
    } else if (s.health === 'HOT' && s.invocations >= 10) {
      recs.push({ type: 'KEEP', agent: s.slug, reason: `High-value agent (${s.invocations} uses, ${s.valueRate} value rate). Consider expanding its checklist for adjacent tasks.` });
    }
  }

  // Global recommendations
  const dead = Object.values(agentStats).filter(s => s.health === 'DEAD').length;
  const hot  = Object.values(agentStats).filter(s => s.health === 'HOT').length;
  if (dead > 10) {
    recs.push({ type: 'GLOBAL', agent: '—', reason: `${dead} dead agents bloat the roster. Schedule a quarterly purge: keep HOT/ACTIVE, archive STALE, delete DEAD.` });
  }
  if (hot <= 3) {
    recs.push({ type: 'GLOBAL', agent: '—', reason: `Only ${hot} HOT agents. Most work flows without the formal hierarchy. Flatten routing: invoke specialists directly, skip PM tier for routine tasks.` });
  }

  return recs;
}

// ── Format report ───────────────────────────────────────────────────────────
function formatReport({ agentStats, sessions, totalInvocations, categories }, recs, asMarkdown) {
  const h1 = s => asMarkdown ? `# ${s}\n` : `\n${'═'.repeat(60)}\n  ${s}\n${'═'.repeat(60)}`;
  const h2 = s => asMarkdown ? `## ${s}\n` : `\n── ${s} ${'─'.repeat(Math.max(0,55-s.length))}`;
  const h3 = s => asMarkdown ? `### ${s}\n` : `\n  ${s}`;
  const pad = (s, n) => String(s || '').padEnd(n);
  const rpad= (s, n) => String(s || '').padStart(n);

  const lines = [];
  lines.push(h1('FieldOps3i — Agent Utilization Report'));
  lines.push(asMarkdown ? `*Generated: ${new Date().toISOString().slice(0,10)}*\n` : `  Generated: ${new Date().toISOString().slice(0,16)}`);
  lines.push('');

  // Overview
  lines.push(h2('Overview'));
  const byHealth = { HOT:0, ACTIVE:0, STALE:0, DEAD:0 };
  for (const s of Object.values(agentStats)) byHealth[s.health] = (byHealth[s.health]||0)+1;

  if (asMarkdown) {
    lines.push(`| Metric | Value |`);
    lines.push(`|---|---|`);
    lines.push(`| Total defined agents | ${Object.keys(agentStats).length} |`);
    lines.push(`| Total invocations | ${totalInvocations} |`);
    lines.push(`| Unique sessions | ${sessions} |`);
    lines.push(`| HOT agents | ${byHealth.HOT} |`);
    lines.push(`| ACTIVE agents | ${byHealth.ACTIVE} |`);
    lines.push(`| STALE agents | ${byHealth.STALE} |`);
    lines.push(`| DEAD agents (never used) | ${byHealth.DEAD} |`);
    lines.push('');
  } else {
    lines.push(`  Agents defined : ${Object.keys(agentStats).length}   |  Invocations: ${totalInvocations}   |  Sessions: ${sessions}`);
    lines.push(`  HOT: ${byHealth.HOT}  ACTIVE: ${byHealth.ACTIVE}  STALE: ${byHealth.STALE}  DEAD: ${byHealth.DEAD}`);
  }

  // Per-tier tables
  for (let tier = 0; tier <= 4; tier++) {
    const tierAgents = Object.values(agentStats)
      .filter(s => s.tier === tier || (tier === 4 && typeof s.tier === 'string' && s.tier > 3))
      .sort((a,b) => b.invocations - a.invocations);
    if (!tierAgents.length) continue;

    const tierLabel = ['Tier 0 — Orchestrator','Tier 1 — Project Managers','Tier 2 — Specialists','Tier 3 — Legacy/Module','Tier 4 — Design Advisory'][tier] || `Tier ${tier}`;
    lines.push(h2(tierLabel));

    if (asMarkdown) {
      lines.push('| Agent | Health | Uses | Sessions | Catch% | Value% | Top Category | Last Used |');
      lines.push('|---|---|---|---|---|---|---|---|');
      for (const s of tierAgents) {
        const healthEmoji = {HOT:'🔥',ACTIVE:'✅',STALE:'⚠️',DEAD:'💀'}[s.health]||'';
        lines.push(`| \`${s.slug}\` | ${healthEmoji} ${s.health} | ${s.invocations} | ${s.sessions} | ${s.catchRate} | ${s.valueRate} | ${s.topCategory} | ${s.lastUsedStr} |`);
      }
      lines.push('');
    } else {
      lines.push(`  ${pad('Agent',42)} ${pad('Health',8)} ${rpad('Uses',5)} ${rpad('Sess',5)} ${rpad('Catch%',7)} ${rpad('Value%',7)} ${pad('Top Cat',14)} Last used`);
      lines.push(`  ${'-'.repeat(105)}`);
      for (const s of tierAgents) {
        lines.push(`  ${pad(s.slug,42)} ${pad(s.health,8)} ${rpad(s.invocations,5)} ${rpad(s.sessions,5)} ${rpad(s.catchRate,7)} ${rpad(s.valueRate,7)} ${pad(s.topCategory,14)} ${s.lastUsedStr}`);
      }
    }
  }

  // Category breakdown
  lines.push(h2('Invocations by Task Category'));
  const catSorted = Object.entries(categories).sort((a,b)=>b[1]-a[1]);
  if (asMarkdown) {
    lines.push('| Category | Count | % of total |');
    lines.push('|---|---|---|');
    for (const [cat, cnt] of catSorted) {
      lines.push(`| ${cat} | ${cnt} | ${(cnt/totalInvocations*100).toFixed(0)}% |`);
    }
    lines.push('');
  } else {
    for (const [cat, cnt] of catSorted) {
      const bar = '█'.repeat(Math.round(cnt/Math.max(...Object.values(categories))*20));
      lines.push(`  ${pad(cat,16)} ${rpad(cnt,4)}  ${bar}`);
    }
  }

  // Dead agents — quick list
  const deadAgents = Object.values(agentStats).filter(s => s.health === 'DEAD').map(s => s.slug);
  if (deadAgents.length) {
    lines.push(h2('Never-Used Agents (candidates for removal)'));
    if (asMarkdown) {
      deadAgents.forEach(a => lines.push(`- \`${a}\``));
      lines.push('');
    } else {
      deadAgents.forEach(a => lines.push(`  ✗  ${a}`));
    }
  }

  // Recommendations
  lines.push(h2('Recommendations'));
  const typeOrder = ['KEEP','REMOVE','EDIT','REVIEW','GLOBAL'];
  const typeIcon  = {KEEP:'✅',REMOVE:'🗑',EDIT:'✏️',REVIEW:'🔍',GLOBAL:'🌐'};
  const recsSorted = recs.sort((a,b)=>typeOrder.indexOf(a.type)-typeOrder.indexOf(b.type));
  if (asMarkdown) {
    for (const r of recsSorted) {
      lines.push(`**${typeIcon[r.type]} ${r.type}** — \`${r.agent}\``);
      lines.push(`> ${r.reason}`);
      lines.push('');
    }
  } else {
    for (const r of recsSorted) {
      lines.push(`  ${typeIcon[r.type]||r.type.padEnd(6)}  ${r.agent}`);
      lines.push(`         ${r.reason}`);
      lines.push('');
    }
  }

  // Footer
  lines.push(asMarkdown
    ? `---\n*Log: \`automation/agent-analytics/invocations.jsonl\` · ${totalInvocations} records · Run \`node scripts/agent-report.cjs --md\` to regenerate.*`
    : `  Log: automation/agent-analytics/invocations.jsonl (${totalInvocations} records)`);

  return lines.join('\n');
}

// ── Entry point ─────────────────────────────────────────────────────────────
const args    = process.argv.slice(2);
const jsonOut = args.includes('--json');
const mdOut   = args.includes('--md');

const log     = loadLog();
const metrics = compute(log);
const recs    = recommend(metrics.agentStats);

if (jsonOut) {
  // Serialize Set fields before JSON output
  const safe = JSON.parse(JSON.stringify(metrics, (_k, v) => v instanceof Set ? [...v] : v));
  console.log(JSON.stringify({ metrics: safe, recommendations: recs }, null, 2));
} else if (mdOut) {
  const report = formatReport(metrics, recs, true);
  const header = `# FieldOps3i — Agent Utilization Summary\n\n> Auto-generated by \`node scripts/agent-report.cjs --md\`  \n> Last updated: ${new Date().toISOString().slice(0,10)}\n\n`;
  fs.writeFileSync(SUMMARY_FILE, header + report, 'utf8');
  console.log(`Written: ${path.relative(ROOT, SUMMARY_FILE)}`);
  console.log(`\nQuick view:\n  node scripts/agent-report.cjs`);
} else {
  console.log(formatReport(metrics, recs, false));
}
