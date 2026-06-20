import { useState } from 'react';

export default function HeroSection() {
  const [query, setQuery] = useState('');

  const handleQuickSearch = (e) => {
    e.preventDefault();
    if (!query.trim()) return;
    const section = document.getElementById('inventory');
    if (section) section.scrollIntoView({ behavior: 'smooth' });
  };

  return (
    <section className="relative bg-gradient-to-br from-blue-900 via-blue-800 to-slate-900 text-white overflow-hidden">
      {/* Background pattern */}
      <div className="absolute inset-0 opacity-10">
        <svg className="w-full h-full" viewBox="0 0 100 100" preserveAspectRatio="none">
          <defs>
            <pattern id="grid" width="10" height="10" patternUnits="userSpaceOnUse">
              <path d="M 10 0 L 0 0 0 10" fill="none" stroke="white" strokeWidth="0.5"/>
            </pattern>
          </defs>
          <rect width="100%" height="100%" fill="url(#grid)" />
        </svg>
      </div>

      <div className="relative max-w-7xl mx-auto px-4 py-24 sm:py-32">
        <div className="max-w-2xl">
          {/* Badge */}
          <div className="inline-flex items-center gap-2 bg-blue-700/50 border border-blue-500/30 rounded-full px-4 py-1.5 text-sm font-medium mb-6">
            <span className="w-2 h-2 rounded-full bg-green-400 animate-pulse" />
            New inventory added weekly
          </div>

          <h1 className="text-5xl sm:text-6xl font-extrabold leading-tight mb-6">
            Find Your
            <span className="block text-transparent bg-clip-text bg-gradient-to-r from-blue-300 to-cyan-300">
              Perfect Drive
            </span>
          </h1>

          <p className="text-lg text-blue-200 mb-10 max-w-lg">
            Browse hundreds of quality pre-owned and new vehicles. Transparent pricing,
            no hidden fees, delivered to your door.
          </p>

          {/* Quick Search */}
          <form onSubmit={handleQuickSearch} className="flex flex-col sm:flex-row gap-3 max-w-lg">
            <input
              type="text"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Search by make, model, or year…"
              className="flex-1 px-5 py-4 rounded-xl text-gray-900 text-sm font-medium
                         focus:outline-none focus:ring-2 focus:ring-blue-400 shadow-lg"
            />
            <button
              type="submit"
              className="bg-blue-500 hover:bg-blue-400 px-8 py-4 rounded-xl font-bold
                         text-sm transition-colors shadow-lg whitespace-nowrap"
            >
              Search Cars
            </button>
          </form>

          {/* Trust signals */}
          <div className="flex flex-wrap gap-6 mt-10 text-sm text-blue-300">
            {[
              { icon: '✅', label: '500+ Vehicles' },
              { icon: '🔒', label: 'Verified History' },
              { icon: '⚡', label: 'Instant Financing' },
              { icon: '🚚', label: 'Free Delivery' },
            ].map(({ icon, label }) => (
              <div key={label} className="flex items-center gap-2">
                <span>{icon}</span>
                <span>{label}</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Wave divider */}
      <div className="absolute bottom-0 left-0 right-0">
        <svg viewBox="0 0 1440 60" fill="none" xmlns="http://www.w3.org/2000/svg">
          <path d="M0,60 C360,0 1080,0 1440,60 L1440,60 L0,60 Z" fill="#f9fafb" />
        </svg>
      </div>
    </section>
  );
}
