/**
 * FieldOps3i — Full post-deploy test matrix
 * Run: NODE_PATH=/Users/abhijit/.npm/_npx/e41f203b7505f1fb/node_modules node /tmp/fieldops_matrix.js [staging|production|both]
 */
const { chromium } = require('playwright');

const ENVS = {
  staging:    { url: 'https://3imedtech.github.io/mri-fieldops-dashboard/staging/', label: 'STAGING' },
  production: { url: 'https://3imedtech.github.io/mri-fieldops-dashboard/',         label: 'PRODUCTION' },
};
const USERS = {
  staging: [
    { role: 'Admin',    email: 'abhijit.s@3imedtech.com', pass: 'Shiva@23S',       expectBody: 'superadmin-mode', expectRole: 'admin' },
    { role: 'Manager',  email: 'manager@3imedtech.com',   pass: 'Shiva@23S',       expectBody: 'viewer-mode manager-mode', expectRole: 'manager' },
    { role: 'Engineer', email: 'engineer@3imedtech.com',  pass: 'Shiva@23S',       expectBody: 'viewer-mode', expectRole: 'viewer' },
  ],
  production: [
    { role: 'Admin',    email: 'abhijit.s@3imedtech.com', pass: 'Shiva@23S',       expectBody: 'superadmin-mode', expectRole: 'admin' },
    { role: 'Manager',  email: 'manager@3imedtech.com',   pass: '3imedtech@123',   expectBody: 'viewer-mode manager-mode', expectRole: 'manager' },
    { role: 'Engineer', email: 'engineer@3imedtech.com',  pass: '!q2w3e4r5t6y7u', expectBody: 'viewer-mode', expectRole: 'viewer' },
  ],
};

const sleep = ms => new Promise(r => setTimeout(r, ms));

async function waitForRole(page, max = 14000) {
  const start = Date.now();
  while (Date.now() - start < max) {
    const body = await page.evaluate(() => document.body.className).catch(() => '');
    if (body) return body;
    await sleep(500);
  }
  return '';
}

async function testRole(page, user, envUrl) {
  const pass = [], fail = [], warn = [];
  const ok  = m => pass.push(m);
  const bad = m => fail.push(m);
  const w   = m => warn.push(m);

  // ── Login ──────────────────────────────────────────────────
  await page.goto(envUrl, { waitUntil: 'networkidle', timeout: 30000 });
  await sleep(800);

  const loginVisible = await page.isVisible('#login-email').catch(() => false);
  if (!loginVisible) { bad('Login form not found'); return { pass, fail, warn }; }

  await page.fill('#login-email', user.email);
  await page.fill('#login-password', user.pass);
  await page.click('button[type="submit"]');

  const bodyClass = await waitForRole(page, 12000);
  const loginErr  = await page.$eval('[role="alert"],.login-error', el => el.textContent.trim()).catch(() => '');
  if (loginErr && loginErr.length > 2) { bad(`Login failed: ${loginErr}`); return { pass, fail, warn }; }
  if (!bodyClass) { bad('Body class never set — auth may have failed'); return { pass, fail, warn }; }
  ok(`Login succeeded`);

  // ── Role resolution ────────────────────────────────────────
  const roleResolved = await page.evaluate(() => typeof _userRole !== 'undefined' ? _userRole : '?');
  if (roleResolved === user.expectRole) ok(`_userRole = ${roleResolved}`);
  else bad(`_userRole = ${roleResolved}, expected ${user.expectRole}`);

  if (bodyClass.includes(user.expectBody.split(' ')[0])) ok(`Body class correct [${bodyClass}]`);
  else bad(`Body class [${bodyClass}], expected to include "${user.expectBody}"`);

  // ── APP_VERSION ────────────────────────────────────────────
  const ver = await page.evaluate(() => typeof APP_VERSION !== 'undefined' ? APP_VERSION : '?');
  if (ver === '1.4.2') ok(`APP_VERSION = ${ver}`);
  else bad(`APP_VERSION = ${ver}, expected 1.4.2`);

  // ── Toast system ───────────────────────────────────────────
  const hasToast = await page.evaluate(() => typeof showToast === 'function');
  if (hasToast) ok('showToast() defined');
  else bad('showToast() missing');

  // ── Dashboard KPIs load ────────────────────────────────────
  await sleep(2500);
  const kpiCount = await page.$$eval('.kpi-value', els => els.filter(e => e.textContent.trim() !== '—' && e.textContent.trim() !== '').length);
  if (kpiCount >= 4) ok(`Dashboard KPIs loaded (${kpiCount} values)`);
  else w(`Only ${kpiCount} KPI values visible — data may not have loaded`);

  // ── Navigate to Contracts ──────────────────────────────────
  await page.evaluate(() => { if (typeof navigate === 'function') navigate('contracts'); });
  await sleep(3500);

  // Match column
  const matchCol = await page.evaluate(() => Array.from(document.querySelectorAll('th')).some(th => th.textContent.trim() === 'Match'));
  if (!matchCol) ok('Match column absent');
  else bad('Match column still present');

  // Data Diagnostics gating
  const diagH3 = await page.evaluate(() =>
    Array.from(document.querySelectorAll(".page.active h3, section:not([style*=\"display:none\"]) h3")).some(h => h.textContent.includes("Data Diagnostics") && window.getComputedStyle(h).display !== "none")
  );
  if (user.role === 'Admin') {
    if (diagH3) ok('Data Diagnostics visible for Admin');
    else bad('Data Diagnostics missing for Admin');
  } else {
    if (!diagH3) ok('Data Diagnostics hidden for non-Admin');
    else bad(`Data Diagnostics visible for ${user.role} (should be hidden)`);
  }

  // Renew buttons
  const renewCount = await page.$$eval('button', bs => bs.filter(b => b.textContent.trim() === 'Renew').length);
  if (user.role === 'Engineer') {
    if (renewCount === 0) ok('Renew buttons absent for Engineer');
    else bad(`Renew buttons visible for Engineer (${renewCount}) — should be 0`);
  } else {
    if (renewCount > 0) ok(`Renew buttons visible (${renewCount})`);
    else bad('No Renew buttons found for Admin/Manager');
  }

  // Renew modal (Admin + Manager)
  if (user.role !== 'Engineer' && renewCount > 0) {
    const btn = await page.$('button:text("Renew")');
    await btn.click(); await sleep(700);
    const modalOpen = await page.evaluate(() => document.getElementById('renew-contract-modal')?.classList.contains('open'));
    if (modalOpen) {
      ok('Renew modal opens');
      const opts = await page.$$eval('#rc-contract-type option', os => os.map(o => o.value));
      const expected = ['warranty','extended_warranty','cmc','amc','labour_contract'];
      const missing = expected.filter(e => !opts.includes(e));
      if (missing.length === 0) ok('All 5 contract types in modal dropdown');
      else bad(`Modal dropdown missing: ${missing.join(', ')}`);
      if (opts.includes('amc')) ok('AMC option present');
      else bad('AMC option missing from dropdown');
      await page.click('#renew-contract-modal button:has-text("Cancel")').catch(() =>
        page.evaluate(() => closeModal('renew-contract-modal'))
      );
      await sleep(400);
    } else {
      const onclick = await btn.evaluate(el => el.getAttribute('onclick'));
      bad(`Renew modal did not open (onclick: ${onclick})`);
    }
  }

  // XLSX button
  const xlsxBtns = await page.$$eval('button', bs =>
    bs.filter(b => b.textContent.includes('Upload XLSX') && window.getComputedStyle(b).display !== 'none').length
  );
  const fileInputDisplay = await page.$eval('#xlsx-upload', el => window.getComputedStyle(el).display).catch(() => 'not found');
  if (user.role === 'Engineer') {
    if (xlsxBtns === 0) ok('XLSX button hidden for Engineer');
    else bad(`XLSX button visible for Engineer (${xlsxBtns})`);
  } else {
    if (xlsxBtns === 1) ok('Single XLSX upload button');
    else if (xlsxBtns === 0) bad('XLSX button missing for Admin/Manager');
    else bad(`Multiple XLSX buttons (${xlsxBtns})`);

    if (fileInputDisplay === 'none') ok('File input correctly hidden');
    else bad(`File input display="${fileInputDisplay}" (should be none)`);
  }

  // Contracts tab nav access
  const contractsNavDisplay = await page.evaluate(() => {
    const el = document.querySelector('[data-page="contracts"]');
    return el ? window.getComputedStyle(el).display : 'not found';
  });
  if (user.role === 'Engineer') {
    if (contractsNavDisplay === 'none') ok('Contracts nav hidden for Engineer');
    else w(`Contracts nav display="${contractsNavDisplay}" for Engineer`);
  } else {
    if (contractsNavDisplay !== 'none' && contractsNavDisplay !== 'not found') ok('Contracts nav visible');
    else bad(`Contracts nav hidden for ${user.role} (display: ${contractsNavDisplay})`);
  }

  // ── Service History tab ────────────────────────────────────
  await page.evaluate(() => { if (typeof navigate === 'function') navigate('tickets'); });
  await sleep(2000);
  const ticketRows = await page.$$eval('table tbody tr', rs => rs.length);
  if (ticketRows > 0) ok(`Service History loaded (${ticketRows} rows visible)`);
  else w('Service History table empty or not loaded');

  // ── PM Schedules tab (PD-006) ──────────────────────────────
  await page.evaluate(() => { if (typeof navigate === 'function') navigate('pm'); });
  await sleep(2500);
  const pmHash = await page.evaluate(() => location.hash);
  if (user.role === 'Engineer') {
    // Engineers can access PM Schedules (read-only) — check they land on it
    const pmRows = await page.$$eval('table tbody tr', rs => rs.length);
    if (pmRows > 0) ok(`PM Schedules loaded for Engineer (${pmRows} rows, read-only)`);
    else w('PM Schedules: no rows visible for Engineer');
    const pmActionCol = await page.evaluate(() => {
      const col = document.querySelector('.pm-action-col');
      return col ? window.getComputedStyle(col).display : 'no action col found';
    });
    if (pmActionCol === 'none' || pmActionCol === 'no action col found') ok('PM action column hidden for Engineer');
    else bad(`PM action column visible for Engineer (display: ${pmActionCol})`);
  } else {
    const pmRows = await page.$$eval('table tbody tr', rs => rs.length);
    if (pmRows > 0) ok(`PM Schedules loaded (${pmRows} rows)`);
    else w('PM Schedules: no rows visible');
    const pmActionCol = await page.evaluate(() => {
      const col = document.querySelector('.pm-action-col');
      return col ? window.getComputedStyle(col).display : 'none';
    });
    if (pmActionCol !== 'none') ok('PM action column visible for Admin/Manager');
    else bad('PM action column hidden for Admin/Manager');
  }

  // ── Engineer Performance tab (PD-006) ─────────────────────
  await page.evaluate(() => { if (typeof navigate === 'function') navigate('engperf'); });
  await sleep(2000);
  const engperfHash = await page.evaluate(() => location.hash);
  if (user.role === 'Engineer') {
    // Engineers should be blocked — navigate() redirects them
    if (!engperfHash.includes('engperf')) ok('Engineer Performance blocked for Engineer (redirected)');
    else bad('Engineer Performance accessible for Engineer (should be blocked)');
  } else {
    const engperfVisible = await page.evaluate(() => {
      const page = document.querySelector('#engperf-section, [id*="engperf"]');
      return !!page;
    });
    if (engperfHash.includes('engperf') || engperfVisible) ok('Engineer Performance accessible for Admin/Manager');
    else w('Engineer Performance: could not confirm — hash=' + engperfHash);
  }

  // ── Console errors (PD-007) — fail if any JS errors on page ──
  // (consoleErrors is populated via page.on listener set in testEnv)
  // Check is deferred to testEnv where we have access to the array

  // ── Page title clean ───────────────────────────────────────
  const pageTitle = await page.title();
  if (!pageTitle.includes('error') && !pageTitle.includes('Error')) ok('Page title clean');

  // ── Screenshot ────────────────────────────────────────────
  const ssPath = `/tmp/matrix_${user.role.toLowerCase()}.png`;
  await page.screenshot({ path: ssPath, fullPage: false });

  return { pass, fail, warn, screenshot: ssPath };
}

async function testEnv(envKey) {
  const env = ENVS[envKey];
  const users = USERS[envKey];
  const browser = await chromium.launch({ headless: true });
  const results = [];

  console.log(`\n${'█'.repeat(60)}`);
  console.log(`  ${env.label}  ${env.url}`);
  console.log('█'.repeat(60));

  for (const user of users) {
    console.log(`\n  ── ${user.role} ──────────────────────────────────────`);
    const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 } });
    const page = await ctx.newPage();

    // Capture console errors
    const consoleErrors = [];
    page.on('console', msg => { if (msg.type() === 'error') consoleErrors.push(msg.text()); });
    page.on('pageerror', err => consoleErrors.push(err.message));

    const r = await testRole(page, user, env.url).catch(err => ({
      pass: [], fail: [`FATAL: ${err.message}`], warn: []
    }));

    // PD-007: filter noise, then fail on real JS errors
    const filtered = consoleErrors.filter(e =>
      !e.includes('favicon') && !e.includes('ERR_BLOCKED') &&
      !e.includes('net::ERR') && !e.includes('Non-Error promise rejection')
    );
    r.consoleErrors = filtered;
    if (filtered.length > 0) {
      r.fail.push(`${filtered.length} JS console error(s) — first: ${filtered[0].substring(0, 120)}`);
    }
    results.push({ role: user.role, ...r });

    r.pass.forEach(m  => console.log(`    ✅ ${m}`));
    r.warn.forEach(m  => console.log(`    ⚡ ${m}`));
    r.fail.forEach(m  => console.log(`    ❌ ${m}`));
    if (r.consoleErrors.length) r.consoleErrors.slice(0,3).forEach(e => console.log(`    🔴 JS: ${e.substring(0,120)}`));
    if (r.screenshot) console.log(`    📸 ${r.screenshot}`);

    await ctx.close();
  }

  await browser.close();
  return results;
}

(async () => {
  const target = process.argv[2] || 'both';
  const envKeys = target === 'both' ? ['staging', 'production'] : [target];
  const allResults = {};

  // Run environments sequentially (parallel would need 2 browsers + more RAM)
  for (const key of envKeys) {
    allResults[key] = await testEnv(key);
  }

  // ── Summary ───────────────────────────────────────────────
  console.log(`\n${'═'.repeat(60)}`);
  console.log('  SUMMARY');
  console.log('═'.repeat(60));
  let totalFail = 0;
  for (const [env, results] of Object.entries(allResults)) {
    console.log(`\n  ${ENVS[env].label}`);
    for (const r of results) {
      const status = r.fail.length === 0 ? '✅' : '❌';
      console.log(`    ${status} ${r.role}: ${r.pass.length} passed, ${r.fail.length} failed, ${r.warn.length} warnings, ${r.consoleErrors?.length || 0} JS errors`);
      r.fail.forEach(f => console.log(`       → ${f}`));
      totalFail += r.fail.length;
    }
  }
  console.log(`\n  Total failures: ${totalFail}`);
  if (totalFail === 0) console.log('  🟢 All checks passed on all tested environments.');
  else console.log('  🔴 Failures found — see details above.');
})();
