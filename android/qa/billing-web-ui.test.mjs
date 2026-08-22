import playwright from '../../../../claude-fallback/node_modules/playwright/index.js';
import { pathToFileURL } from 'node:url';
import path from 'node:path';
import assert from 'node:assert/strict';

const browser = await playwright.chromium.launch({ executablePath: 'C:/Program Files (x86)/Google/Chrome/Application/chrome.exe', headless: true });
try {
  const page = await browser.newPage();
  await page.addInitScript(() => {
    window.__billingCalls = [];
    window.DaimonBilling = {
      subscribe: () => window.__billingCalls.push('subscribe'),
      restore: () => window.__billingCalls.push('restore'),
    };
  });
  await page.goto(pathToFileURL(path.resolve('index.html')).href);
  assert.equal(await page.locator('#billingPanel').evaluate(el => el.classList.contains('on')), true);
  assert.equal(await page.locator('.mode-list').evaluate(el => el.classList.contains('billing-locked')), true);
  await page.evaluate(() => window.dispatchEvent(new CustomEvent('daimon-billing', { detail: { state: 'ENTITLED', price: '￥2,500' } })));
  assert.equal(await page.locator('.mode-list').evaluate(el => el.classList.contains('billing-locked')), false);
  await page.evaluate(() => window.dispatchEvent(new CustomEvent('daimon-billing', { detail: { state: 'NETWORK_ERROR' } })));
  assert.match(await page.locator('#billingStatus').textContent(), /通信できません/);
  await page.locator('#billingSubscribe').click();
  await page.locator('#billingRestore').click();
  assert.deepEqual(await page.evaluate(() => window.__billingCalls), ['subscribe', 'restore']);
  console.log('BILLING_WEB_UI_TEST_PASS');
} finally { await browser.close(); }
