import { useState } from 'react';

const INITIAL = { name: '', email: '', phone: '', message: '' };

export default function ContactForm() {
  const [form, setForm] = useState(INITIAL);
  const [errors, setErrors] = useState({});
  const [status, setStatus] = useState('idle'); // idle | loading | success | error

  const validate = () => {
    const e = {};
    if (!form.name.trim())                     e.name    = 'Name is required';
    if (!form.email.match(/^[^\s@]+@[^\s@]+\.[^\s@]+$/)) e.email = 'Valid email required';
    if (!form.message.trim())                  e.message = 'Message is required';
    return e;
  };

  const handleChange = (field) => (e) => {
    setForm(f => ({ ...f, [field]: e.target.value }));
    if (errors[field]) setErrors(er => ({ ...er, [field]: undefined }));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    const errs = validate();
    if (Object.keys(errs).length) { setErrors(errs); return; }

    setStatus('loading');
    try {
      const res = await fetch('/api/inquiries', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(form),
      });
      if (res.ok) {
        setStatus('success');
        setForm(INITIAL);
      } else {
        setStatus('error');
      }
    } catch {
      setStatus('error');
    }
  };

  if (status === 'success') {
    return (
      <div className="bg-white/10 backdrop-blur-sm rounded-2xl p-10 text-center">
        <div className="text-5xl mb-4">🎉</div>
        <h3 className="text-2xl font-bold text-white mb-2">Message Sent!</h3>
        <p className="text-blue-200">One of our team members will reach out within 24 hours.</p>
        <button
          onClick={() => setStatus('idle')}
          className="mt-6 text-blue-300 underline text-sm hover:text-white"
        >
          Send another message
        </button>
      </div>
    );
  }

  return (
    <form
      onSubmit={handleSubmit}
      className="bg-white/10 backdrop-blur-sm rounded-2xl p-6 sm:p-8 space-y-4"
      noValidate
    >
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
        {/* Name */}
        <div>
          <label className="block text-sm font-medium text-blue-100 mb-1">
            Full Name <span className="text-red-400">*</span>
          </label>
          <input
            type="text"
            value={form.name}
            onChange={handleChange('name')}
            placeholder="Jane Smith"
            className={`w-full px-4 py-3 rounded-xl text-gray-900 text-sm outline-none
              focus:ring-2 focus:ring-blue-400 ${errors.name ? 'ring-2 ring-red-400' : ''}`}
          />
          {errors.name && <p className="text-red-300 text-xs mt-1">{errors.name}</p>}
        </div>

        {/* Email */}
        <div>
          <label className="block text-sm font-medium text-blue-100 mb-1">
            Email <span className="text-red-400">*</span>
          </label>
          <input
            type="email"
            value={form.email}
            onChange={handleChange('email')}
            placeholder="jane@example.com"
            className={`w-full px-4 py-3 rounded-xl text-gray-900 text-sm outline-none
              focus:ring-2 focus:ring-blue-400 ${errors.email ? 'ring-2 ring-red-400' : ''}`}
          />
          {errors.email && <p className="text-red-300 text-xs mt-1">{errors.email}</p>}
        </div>
      </div>

      {/* Phone */}
      <div>
        <label className="block text-sm font-medium text-blue-100 mb-1">
          Phone <span className="text-blue-300 text-xs">(optional)</span>
        </label>
        <input
          type="tel"
          value={form.phone}
          onChange={handleChange('phone')}
          placeholder="+1 (555) 000-0000"
          className="w-full px-4 py-3 rounded-xl text-gray-900 text-sm outline-none focus:ring-2 focus:ring-blue-400"
        />
      </div>

      {/* Message */}
      <div>
        <label className="block text-sm font-medium text-blue-100 mb-1">
          Message <span className="text-red-400">*</span>
        </label>
        <textarea
          rows={4}
          value={form.message}
          onChange={handleChange('message')}
          placeholder="Tell us what you're looking for, your budget, or any questions…"
          className={`w-full px-4 py-3 rounded-xl text-gray-900 text-sm outline-none
            focus:ring-2 focus:ring-blue-400 resize-none ${errors.message ? 'ring-2 ring-red-400' : ''}`}
        />
        {errors.message && <p className="text-red-300 text-xs mt-1">{errors.message}</p>}
      </div>

      {status === 'error' && (
        <p className="text-red-300 text-sm bg-red-900/30 rounded-lg px-4 py-2">
          ⚠️ Something went wrong. Please try again or call us directly.
        </p>
      )}

      <button
        type="submit"
        disabled={status === 'loading'}
        className="w-full bg-white text-blue-900 font-bold py-4 rounded-xl
                   hover:bg-blue-50 transition-colors disabled:opacity-60 text-sm tracking-wide"
      >
        {status === 'loading' ? (
          <span className="flex items-center justify-center gap-2">
            <svg className="animate-spin h-4 w-4" fill="none" viewBox="0 0 24 24">
              <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"/>
              <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8z"/>
            </svg>
            Sending…
          </span>
        ) : 'Send Message'}
      </button>
    </form>
  );
}
