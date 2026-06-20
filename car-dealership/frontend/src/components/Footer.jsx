export default function Footer() {
  const year = new Date().getFullYear();

  return (
    <footer className="bg-slate-900 text-slate-400 text-sm">
      <div className="max-w-7xl mx-auto px-4 py-10 grid grid-cols-1 sm:grid-cols-3 gap-8">
        <div>
          <div className="font-extrabold text-white text-lg mb-2">🚗 PremierAuto</div>
          <p className="text-slate-500 leading-relaxed">
            Quality vehicles, transparent pricing, exceptional service.
          </p>
        </div>

        <div>
          <h4 className="font-semibold text-white mb-3">Quick Links</h4>
          <ul className="space-y-2">
            {['Inventory', 'Financing', 'About Us', 'Contact'].map(link => (
              <li key={link}>
                <a href="#" className="hover:text-white transition-colors">{link}</a>
              </li>
            ))}
          </ul>
        </div>

        <div>
          <h4 className="font-semibold text-white mb-3">Contact</h4>
          <address className="not-italic space-y-1 text-slate-500">
            <p>123 Auto Row, Suite 100</p>
            <p>Anytown, USA 10001</p>
            <p className="mt-2">
              <a href="tel:+15550001234" className="hover:text-white transition-colors">
                📞 (555) 000-1234
              </a>
            </p>
            <p>
              <a href="mailto:sales@premierauto.com" className="hover:text-white transition-colors">
                ✉️ sales@premierauto.com
              </a>
            </p>
          </address>
        </div>
      </div>

      <div className="border-t border-slate-800 px-4 py-4 text-center text-slate-600 text-xs">
        © {year} PremierAuto. All rights reserved.
      </div>
    </footer>
  );
}
