import { useState } from 'react';

export default function CarCard({ car }) {
  const [showContact, setShowContact] = useState(false);

  const formattedPrice = new Intl.NumberFormat('en-US', {
    style: 'currency', currency: 'USD', maximumFractionDigits: 0,
  }).format(car.price);

  const formattedMileage = new Intl.NumberFormat('en-US').format(car.mileage);

  return (
    <article className="bg-white rounded-2xl shadow-md overflow-hidden hover:shadow-xl transition-shadow duration-300">
      {/* Image */}
      <div className="relative h-52 bg-gray-200">
        {car.image_url ? (
          <img
            src={car.image_url}
            alt={`${car.year} ${car.make} ${car.model}`}
            className="w-full h-full object-cover"
            loading="lazy"
          />
        ) : (
          <div className="flex items-center justify-center h-full text-gray-400">
            <svg className="w-16 h-16" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1}
                d="M8 17l4 4 4-4m-4-5v9M20.88 18.09A5 5 0 0018 9h-1.26A8 8 0 103 16.29" />
            </svg>
          </div>
        )}
        <span className={`absolute top-3 right-3 text-xs font-semibold px-2 py-1 rounded-full ${
          car.condition === 'new' ? 'bg-green-100 text-green-800' : 'bg-blue-100 text-blue-800'
        }`}>
          {car.condition === 'new' ? 'NEW' : 'PRE-OWNED'}
        </span>
      </div>

      {/* Details */}
      <div className="p-5">
        <h3 className="text-lg font-bold text-gray-900 truncate">
          {car.year} {car.make} {car.model}
        </h3>
        <p className="text-sm text-gray-500 mb-3">{car.trim || ''}</p>

        <div className="grid grid-cols-2 gap-2 text-sm text-gray-600 mb-4">
          <span>🛣️ {formattedMileage} mi</span>
          <span>⛽ {car.fuel_type || 'Gasoline'}</span>
          <span>🎨 {car.color || 'N/A'}</span>
          <span>⚙️ {car.transmission || 'Automatic'}</span>
        </div>

        <div className="flex items-center justify-between mt-2">
          <span className="text-2xl font-extrabold text-blue-700">{formattedPrice}</span>
          <button
            onClick={() => setShowContact(true)}
            className="bg-blue-600 hover:bg-blue-700 text-white text-sm font-medium px-4 py-2 rounded-lg transition-colors"
          >
            Inquire
          </button>
        </div>
      </div>

      {/* Quick Inquiry Modal */}
      {showContact && (
        <QuickInquiryModal car={car} onClose={() => setShowContact(false)} />
      )}
    </article>
  );
}

function QuickInquiryModal({ car, onClose }) {
  const [form, setForm] = useState({ name: '', email: '', message: `I'm interested in the ${car.year} ${car.make} ${car.model}.` });
  const [status, setStatus] = useState('idle');

  const submit = async (e) => {
    e.preventDefault();
    setStatus('loading');
    try {
      const res = await fetch('/api/inquiries', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ...form, carId: car.id }),
      });
      setStatus(res.ok ? 'success' : 'error');
    } catch {
      setStatus('error');
    }
  };

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-2xl p-6 w-full max-w-md shadow-2xl">
        <div className="flex justify-between items-start mb-4">
          <h3 className="font-bold text-gray-900">Quick Inquiry</h3>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600">✕</button>
        </div>
        {status === 'success' ? (
          <p className="text-green-600 font-medium py-4 text-center">
            ✅ Inquiry sent! We'll contact you shortly.
          </p>
        ) : (
          <form onSubmit={submit} className="space-y-3">
            <input required placeholder="Your name" value={form.name}
              onChange={e => setForm(f => ({ ...f, name: e.target.value }))}
              className="w-full border rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none" />
            <input required type="email" placeholder="Email address" value={form.email}
              onChange={e => setForm(f => ({ ...f, email: e.target.value }))}
              className="w-full border rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none" />
            <textarea rows={3} value={form.message}
              onChange={e => setForm(f => ({ ...f, message: e.target.value }))}
              className="w-full border rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none" />
            {status === 'error' && <p className="text-red-500 text-sm">Failed to send. Please try again.</p>}
            <button type="submit" disabled={status === 'loading'}
              className="w-full bg-blue-600 text-white py-2 rounded-lg font-medium text-sm hover:bg-blue-700 disabled:opacity-50">
              {status === 'loading' ? 'Sending…' : 'Send Inquiry'}
            </button>
          </form>
        )}
      </div>
    </div>
  );
}
