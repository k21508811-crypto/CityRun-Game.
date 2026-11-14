import express from 'express';
import Stripe from 'stripe';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const app = express();
const port = Number(process.env.PORT || 3000);
const baseUrl = (process.env.BASE_URL || `http://localhost:${port}`).replace(/\/$/, '');
const dbPath = path.resolve(process.env.LICENSES_DB || './data/licenses.json');
const stripe = process.env.STRIPE_SECRET_KEY ? new Stripe(process.env.STRIPE_SECRET_KEY) : null;

function readDb() {
  try { return JSON.parse(fs.readFileSync(dbPath, 'utf8')); }
  catch { return { licenses: [], processedEvents: [] }; }
}
function writeDb(db) {
  fs.mkdirSync(path.dirname(dbPath), { recursive: true });
  const tmp = `${dbPath}.tmp`;
  fs.writeFileSync(tmp, JSON.stringify(db, null, 2), { mode: 0o600 });
  fs.renameSync(tmp, dbPath);
}
function makeKey() {
  const raw = crypto.randomBytes(18).toString('hex').toUpperCase();
  return `CITY-${raw.match(/.{1,6}/g).join('-')}`;
}
function safeEqual(a, b) {
  const aa = Buffer.from(a || ''); const bb = Buffer.from(b || '');
  return aa.length === bb.length && crypto.timingSafeEqual(aa, bb);
}

app.use('/api/stripe/webhook', express.raw({ type: 'application/json' }));
app.use(express.json({ limit: '32kb' }));
app.use(express.static(path.join(__dirname, 'public')));

app.get('/api/config', (_req, res) => res.json({ product: process.env.PRODUCT_NAME || 'City Run PC License', priceCents: Number(process.env.PRICE_CENTS || 23300), currency: (process.env.CURRENCY || 'rub').toUpperCase(), paymentsReady: Boolean(stripe) }));

app.post('/api/checkout', async (_req, res) => {
  if (!stripe) return res.status(503).json({ error: 'Оплата ещё не настроена. Владелец должен добавить Stripe secret key.' });
  const amount = Number(process.env.PRICE_CENTS || 23300);
  const currency = (process.env.CURRENCY || 'rub').toLowerCase();
  if (!Number.isInteger(amount) || amount < 50) return res.status(500).json({ error: 'Неверная цена товара в конфигурации.' });
  try {
    const session = await stripe.checkout.sessions.create({
      mode: 'payment',
      line_items: [{ price_data: { currency, unit_amount: amount, product_data: { name: process.env.PRODUCT_NAME || 'City Run PC License' } }, quantity: 1 }],
      success_url: `${baseUrl}/success.html?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${baseUrl}/?cancelled=1`,
      metadata: { product: 'cityrun-pc-license' }
    });
    res.json({ url: session.url });
  } catch (error) {
    console.error('Checkout error:', error.message);
    res.status(502).json({ error: 'Не удалось создать платёж. Попробуйте позже.' });
  }
});

app.post('/api/stripe/webhook', (req, res) => {
  if (!stripe || !process.env.STRIPE_WEBHOOK_SECRET) return res.status(503).send('Webhook is not configured');
  let event;
  try { event = stripe.webhooks.constructEvent(req.body, req.headers['stripe-signature'], process.env.STRIPE_WEBHOOK_SECRET); }
  catch (error) { return res.status(400).send(`Invalid signature: ${error.message}`); }
  const db = readDb();
  if (db.processedEvents.includes(event.id)) return res.json({ received: true, duplicate: true });
  if (event.type === 'checkout.session.completed') {
    const session = event.data.object;
    if (session.payment_status === 'paid' && session.metadata?.product === 'cityrun-pc-license') {
      db.licenses.push({ key: makeKey(), sessionId: session.id, email: session.customer_details?.email || null, createdAt: new Date().toISOString(), machineId: null, activatedAt: null, revoked: false });
    }
  }
  db.processedEvents.push(event.id);
  writeDb(db);
  res.json({ received: true });
});

app.get('/api/order/:sessionId', async (req, res) => {
  if (!stripe) return res.status(503).json({ error: 'Payments are not configured.' });
  try {
    const session = await stripe.checkout.sessions.retrieve(req.params.sessionId);
    if (session.payment_status !== 'paid') return res.status(402).json({ error: 'Payment not completed.' });
    const license = readDb().licenses.find(item => item.sessionId === session.id);
    if (!license) return res.status(202).json({ pending: true, message: 'Платёж подтверждается. Обновите страницу через несколько секунд.' });
    res.json({ key: license.key });
  } catch { res.status(404).json({ error: 'Заказ не найден.' }); }
});

app.post('/api/activate', (req, res) => {
  const key = String(req.body?.key || '').trim().toUpperCase();
  const machineId = String(req.body?.machineId || '').trim();
  if (!/^CITY-(?:[A-F0-9]{6}-){5}[A-F0-9]{6}$/.test(key) || machineId.length < 8 || machineId.length > 128) return res.status(400).json({ valid: false, error: 'Неверный ключ или идентификатор устройства.' });
  const db = readDb();
  const license = db.licenses.find(item => safeEqual(item.key, key));
  if (!license || license.revoked) return res.status(403).json({ valid: false, error: 'Ключ не найден или отозван.' });
  if (license.machineId && license.machineId !== machineId) return res.status(409).json({ valid: false, error: 'Ключ уже активирован на другом устройстве.' });
  license.machineId = machineId;
  license.activatedAt ||= new Date().toISOString();
  writeDb(db);
  res.json({ valid: true, product: 'City Run PC', message: 'Ключ успешно активирован.' });
});

app.get('/health', (_req, res) => res.json({ ok: true }));
app.listen(port, () => console.log(`City Run portal listening on ${port}`));
