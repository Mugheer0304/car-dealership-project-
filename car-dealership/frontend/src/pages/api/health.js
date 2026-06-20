export default function handler(req, res) {
  res.status(200).json({ status: 'ok', service: 'frontend', timestamp: new Date().toISOString() });
}
