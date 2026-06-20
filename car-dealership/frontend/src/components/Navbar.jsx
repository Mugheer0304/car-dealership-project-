import { useState } from 'react';
import Link from 'next/link';

const NAV_LINKS = [
  { href: '/#inventory', label: 'Inventory' },
  { href: '/#contact',   label: 'Contact' },
];

export default function Navbar() {
  const [open, setOpen] = useState(false);

  return (
    <header className="bg-blue-900 text-white sticky top-0 z-50 shadow-md">
      <div className="max-w-7xl mx-auto px-4 py-4 flex items-center justify-between">
        {/* Logo */}
        <Link href="/" className="flex items-center gap-2 font-extrabold text-xl tracking-tight">
          <span className="text-2xl">🚗</span>
          <span>Premier<span className="text-blue-300">Auto</span></span>
        </Link>

        {/* Desktop nav */}
        <nav className="hidden md:flex items-center gap-6 text-sm font-medium">
          {NAV_LINKS.map(({ href, label }) => (
            <a
              key={label}
              href={href}
              className="text-blue-200 hover:text-white transition-colors"
            >
              {label}
            </a>
          ))}
          <a
            href="tel:+15550001234"
            className="bg-blue-600 hover:bg-blue-500 px-4 py-2 rounded-lg transition-colors"
          >
            📞 (555) 000-1234
          </a>
        </nav>

        {/* Mobile hamburger */}
        <button
          className="md:hidden p-2 rounded-lg hover:bg-blue-800"
          onClick={() => setOpen(!open)}
          aria-label="Toggle menu"
        >
          <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            {open
              ? <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
              : <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />}
          </svg>
        </button>
      </div>

      {/* Mobile menu */}
      {open && (
        <div className="md:hidden border-t border-blue-800 px-4 py-4 space-y-3 text-sm font-medium">
          {NAV_LINKS.map(({ href, label }) => (
            <a
              key={label}
              href={href}
              className="block text-blue-200 hover:text-white py-1"
              onClick={() => setOpen(false)}
            >
              {label}
            </a>
          ))}
        </div>
      )}
    </header>
  );
}
