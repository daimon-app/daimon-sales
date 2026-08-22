export function loadConfig(env = process.env) {
  const required = ['EXPECTED_PACKAGE_NAME', 'EXPECTED_PRODUCT_ID', 'INTERNAL_API_KEY', 'TOKEN_HMAC_KEY'];
  for (const key of required) if (!env[key]) throw new Error(`missing required environment: ${key}`);
  const mode = env.BILLING_MODE || 'production';
  if (!['fake', 'production'].includes(mode)) throw new Error('BILLING_MODE must be fake or production');
  if (mode === 'production' && !env.GOOGLE_PLAY_CREDENTIALS_FILE) throw new Error('production verifier credentials are not configured');
  return Object.freeze({ port: Number(env.PORT || 8080), mode, packageName: env.EXPECTED_PACKAGE_NAME,
    productId: env.EXPECTED_PRODUCT_ID, basePlanId: env.EXPECTED_BASE_PLAN_ID || '', apiKey: env.INTERNAL_API_KEY,
    hmacKey: env.TOKEN_HMAC_KEY, credentialsFile: env.GOOGLE_PLAY_CREDENTIALS_FILE || '',
    timeoutMs: Number(env.GOOGLE_PLAY_TIMEOUT_MS || 5000), maxRetries: Number(env.GOOGLE_PLAY_MAX_RETRIES || 2), cacheMs: Number(env.VERIFICATION_CACHE_MS || 60000),
    auditFile: env.AUDIT_LOG_FILE || './data/audit.jsonl', ledgerFile: env.LEDGER_FILE || './data/ledger.json',
    rateLimitWindowMs: Number(env.RATE_LIMIT_WINDOW_MS || 60000), rateLimitMax: Number(env.RATE_LIMIT_MAX || 60) });
}
