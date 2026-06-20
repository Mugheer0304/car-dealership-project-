// pages/api/cars.js  –  thin BFF proxy to backend service
export default async function handler(req, res) {
  const { method, query } = req;

  if (method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const backendUrl = process.env.BACKEND_URL;
  const params = new URLSearchParams(query).toString();

  try {
    const upstream = await fetch(`${backendUrl}/api/cars?${params}`, {
      headers: { 'x-internal': '1', 'x-forwarded-for': req.headers['x-forwarded-for'] || '' },
      signal: AbortSignal.timeout(5000),
    });

    const data = await upstream.json();
    res.setHeader('Cache-Control', 'public, s-maxage=60, stale-while-revalidate=300');
    return res.status(upstream.status).json(data);
  } catch (err) {
    console.error('[cars proxy]', err.message);
    return res.status(502).json({ error: 'Upstream unavailable' });
  }
}
