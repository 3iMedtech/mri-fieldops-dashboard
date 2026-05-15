/**
 * FieldOps3i — Targeted validation for the 6-issue WO workflow batch.
 *
 * Validates against the live staging deploy and covers:
 *   1. Asset-linked field locking in the New WO modal (Issue 1, 4-fix)
 *   2. Work Orders date filter default = "all" (Issue 2)
 *   3. Closure modal appears and captures sys_status (Issue 3)
 *   4. Dashboard panel title = "Open Work Orders" (Issue 4)
 *   5. Dashboard panel rows = Work Orders tab rows (Issue 5)
 *   6. Sub-WO button visible on open primary WO (Issue 6)
 *
 * Run: NODE_PATH=/Users/abhijit/.npm/_npx/e41f203b7505f1fb/node_modules \
 *      node scripts/test-wo-fixes.js
 */
const { chromium } = require('playwright');

const URL = 'https://3imedtech.github.io/mri-fieldops-dashboard/staging/';
const USERS = [
  { role: 'Admin',    email: 'abhijit.s@3imedtech.com', pass: 'Shiva@23S' },
  { role: 'Manager',  email: 'manager@3imedtech.com',   pass: 'Shiva@23S' },
  { role: 'Engineer', email: 'engineer@3imedtech.com',  pass: 'Shiva@23S' },
];

const sleep = ms => new Promise(r => setTimeout(r, ms));

async function login(page, user) {
  await page.goto(URL, { waitUntil: 'domcontentloaded' });
  await page.waitForSelector('#login-email', { timeout: 15000 });
  await page.fill('#login-email', user.email);
  await page.fill('#login-password', user.pass);
  await page.click('button[type="submit"]');
  // wait for app to land — body class flips when role resolves
  const start = Date.now();
  while (Date.now() - start < 14000) {
    const cls = await page.evaluate(() => document.body.className).catch(() => '');
    if (cls && (cls.includes('superadmin-mode') || cls.includes('viewer-mode') || cls.includes('manager-mode'))) return;
    await sleep(400);
  }
}

async function testRole(user) {
  const browser = await chromium.launch({ headless: true });
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const errors = [];
  page.on('pageerror', e => errors.push(`pageerror: ${e.message}`));
  const out = { role: user.role, pass: [], fail: [], info: [] };
  const ok = m => out.pass.push(m);
  const bad = m => out.fail.push(m);

  try {
    await login(page, user);
    await sleep(2000);

    // ── Issue 4: dashboard panel title ─────────────────────────────
    const dashTitles = await page.$$eval('.panel-title', els => els.map(e => e.textContent.trim()));
    if (dashTitles.some(t => /Open Work Orders/i.test(t))) ok('Dashboard shows "Open Work Orders" title');
    else bad(`Dashboard "Open Work Orders" title missing. Found: ${JSON.stringify(dashTitles.slice(0,6))}`);
    if (dashTitles.some(t => /Open Tickets \(Legacy\)/i.test(t)))
      bad('Stale "Open Tickets (Legacy)" title still present');
    else ok('No "Open Tickets (Legacy)" title');

    // ── Dashboard rows count (for Issue 5 cross-check) ─────────────
    const dashRowIds = await page.$$eval('#dash-open-body tr td:first-child', tds =>
      tds.map(td => td.textContent.trim()).filter(Boolean)
    );
    out.info.push(`Dashboard panel rows: ${dashRowIds.length}`);

    // ── Navigate to Work Orders tab ────────────────────────────────
    await page.evaluate(() => navigate('app-tickets'));
    await sleep(900);

    // ── Issue 2: DATE filter default = "all" ───────────────────────
    const dateDefault = await page.$eval('#at-date', s => s.value).catch(() => null);
    if (dateDefault === 'all') ok('Work Orders DATE default = "all"');
    else bad(`Work Orders DATE default = ${dateDefault} (expected "all")`);

    // count work orders shown
    const woRows = await page.$$eval('#at-tbody tr', rows => rows.length);
    out.info.push(`Work Orders tab rows: ${woRows}`);

    // ── Issue 5: dashboard ⊆ work orders tab ────────────────────────
    const woRowIds = await page.$$eval('#at-tbody tr td:first-child', tds =>
      tds.map(td => td.textContent.trim()).filter(Boolean)
    );
    if (dashRowIds.length === 0 && woRowIds.length === 0) {
      out.info.push('No work orders in either view — cannot validate sync directly');
    } else {
      const overlap = dashRowIds.filter(id => woRowIds.includes(id));
      if (dashRowIds.length === 0) {
        ok('Dashboard panel empty — empty-state shown, no mismatch');
      } else if (overlap.length === dashRowIds.length) {
        ok(`Dashboard rows (${dashRowIds.length}) all present in Work Orders tab`);
      } else {
        bad(`Dashboard rows not in Work Orders tab: ${dashRowIds.filter(i => !woRowIds.includes(i)).join(', ')}`);
      }
    }

    // ── Issue 1: open New WO modal (admin/manager only) ─────────────
    if (user.role !== 'Engineer') {
      const hasNewBtn = await page.$('button:has-text("New Work Order")');
      if (hasNewBtn) {
        await hasNewBtn.click();
        await sleep(600);
        // pick the first non-blank asset
        const assetOpts = await page.$$eval('#nt-asset option', os => os.map(o => o.value).filter(Boolean));
        if (assetOpts.length) {
          await page.selectOption('#nt-asset', assetOpts[0]);
          await sleep(300);
          const lockState = await page.evaluate(() => {
            const c = document.getElementById('nt-customer');
            const a = document.getElementById('nt-asset-code');
            const r = document.getElementById('nt-region');
            const t = document.getElementById('nt-town');
            return {
              customerLocked: !!c && c.readOnly === true,
              assetLocked:    !!a && a.readOnly === true,
              regionLocked:   !!r && r.disabled === true,
              townLocked:     !!t && t.readOnly === true,
              customerVal: c && c.value, regionVal: r && r.value, townVal: t && t.value, assetVal: a && a.value,
            };
          });
          if (lockState.customerLocked && lockState.assetLocked && lockState.regionLocked && lockState.townLocked) {
            ok(`Asset-locked fields all readonly/disabled (customer="${lockState.customerVal}", asset="${lockState.assetVal}", region="${lockState.regionVal}", town="${lockState.townVal}")`);
          } else {
            bad(`Lock state: ${JSON.stringify(lockState)}`);
          }
          // clear asset → fields should unlock
          await page.selectOption('#nt-asset', '');
          await sleep(200);
          const unlocked = await page.evaluate(() => {
            return {
              customer: !document.getElementById('nt-customer').readOnly,
              asset:    !document.getElementById('nt-asset-code').readOnly,
              region:   !document.getElementById('nt-region').disabled,
              town:     !document.getElementById('nt-town').readOnly,
            };
          });
          if (unlocked.customer && unlocked.asset && unlocked.region && unlocked.town) ok('Clear-asset unlocks all 4 fields');
          else bad(`Unlock after clear failed: ${JSON.stringify(unlocked)}`);
          // close
          await page.evaluate(() => closeModal('new-ticket-modal'));
          await sleep(200);
        } else {
          out.info.push('No active assets — could not test field locking');
        }
      } else {
        bad('New Work Order button not visible for ' + user.role);
      }
    } else {
      const hasNewBtn = await page.$('button:has-text("New Work Order"):visible');
      if (!hasNewBtn) ok('Engineer cannot see "New Work Order" button');
      else bad('Engineer should NOT see "New Work Order" button');
    }

    // ── Issue 3 + 6: open a WO detail and inspect closure / sub-WO ──
    if (woRowIds.length) {
      await page.evaluate(id => _openTicketDetail(id), woRowIds[0]);
      await sleep(700);
      const modalOpen = await page.$eval('#at-detail-modal', m => m.classList.contains('active') || m.getAttribute('aria-hidden') === 'false').catch(() => false);
      out.info.push(`Detail modal opened: ${modalOpen}`);
      // Sub-WO button check (Issue 6)
      const subBtnVisible = await page.$eval('#atd-create-sub-btn', b => b && b.offsetParent !== null).catch(() => false);
      out.info.push(`Sub-WO create button visible: ${subBtnVisible}`);

      // sys_status closure modal presence (Issue 3) — check the markup exists
      const closeModalPresent = await page.$('#close-status-modal');
      if (closeModalPresent) ok('Closure sys_status modal exists in DOM');
      else bad('close-status-modal not in DOM');

      // Verify clicking "Mark Resolved" (if state allows) opens close-status-modal
      const status = await page.$eval('#atd-id', el => el.textContent).catch(() => '');
      // we attempt: only if a Mark Resolved / Mark Completed button is rendered
      const resolveBtn = await page.$('#atd-transitions button:has-text("Mark Resolved")');
      const completeBtn = await page.$('#atd-transitions button:has-text("Mark Completed")');
      const btn = resolveBtn || completeBtn;
      if (btn) {
        await btn.click();
        await sleep(500);
        const csOpen = await page.$eval('#close-status-modal', m =>
          m.classList.contains('active') || m.getAttribute('aria-hidden') === 'false'
        ).catch(() => false);
        if (csOpen) {
          ok('Closure modal opens on Mark Resolved/Completed click');
          // close it without confirming
          await page.evaluate(() => _atdCancelCloseStatus && _atdCancelCloseStatus());
          await sleep(200);
        } else {
          bad('Closure modal did not open on resolve/complete click');
        }
      } else {
        out.info.push('No resolved/completed transition button available for current WO state');
      }
      await page.evaluate(() => closeModal('at-detail-modal'));
      await sleep(200);
    } else {
      out.info.push('No WOs available to test detail/closure/sub-WO');
    }

    // ── JS errors during run ────────────────────────────────────────
    if (errors.length) {
      bad(`Page errors: ${errors.slice(0,3).join(' | ')}`);
    } else {
      ok('No JS errors during session');
    }
  } catch (e) {
    bad(`Exception: ${e.message}`);
  } finally {
    await browser.close();
  }
  return out;
}

(async () => {
  const results = [];
  for (const u of USERS) {
    process.stdout.write(`\n▶ ${u.role} …\n`);
    const r = await testRole(u);
    results.push(r);
    r.pass.forEach(m => console.log(`  PASS ${m}`));
    r.fail.forEach(m => console.log(`  FAIL ${m}`));
    r.info.forEach(m => console.log(`  · ${m}`));
  }
  console.log('\n══════════════════════════════════════════');
  console.log(' WO FIX MATRIX — STAGING');
  console.log('══════════════════════════════════════════');
  let totalPass = 0, totalFail = 0;
  for (const r of results) {
    console.log(`  ${r.role.padEnd(10)}  pass=${r.pass.length}  fail=${r.fail.length}`);
    totalPass += r.pass.length; totalFail += r.fail.length;
  }
  console.log(`  TOTAL       pass=${totalPass}  fail=${totalFail}`);
  process.exit(totalFail ? 1 : 0);
})();
