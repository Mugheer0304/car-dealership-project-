export default async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).end();

  const { name, email, phone, message, carId } = req.body;

  if (!name || !email || !message) {
    return res.status(400).json({ error: 'Name, email, and message are required.' });
  }

  try {
    const upstream = await fetch(`${process.env.BACKEND_URL}/api/inquiries`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-internal': '1' },
      body: JSON.stringify({ name, email, phone, message, car_id: carId }),
      signal: AbortSignal.timeout(5000),
    });

    const data = await upstream.json();
    return res.status(upstream.status).json(data);
  } catch (err) {
    console.error('[inquiries proxy]', err.message);
    return res.status(502).json({ error: 'Could not submit inquiry. Please try again.' });
  }
}
