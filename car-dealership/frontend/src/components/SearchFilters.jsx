// SearchFilters.jsx
export function SearchFilters({ filters, setFilters, onSearch }) {
  const MAKES = ['Toyota', 'Honda', 'Ford', 'Chevrolet', 'BMW', 'Mercedes', 'Audi', 'Tesla'];
  const YEARS = Array.from({ length: 12 }, (_, i) => 2024 - i);

  const handleChange = (key) => (e) => setFilters(f => ({ ...f, [key]: e.target.value }));

  return (
    <div className="bg-white rounded-2xl shadow-sm border p-4">
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-5 gap-3">
        <select value={filters.make} onChange={handleChange('make')}
          className="border rounded-lg px-3 py-2 text-sm text-gray-700 focus:ring-2 focus:ring-blue-500 outline-none">
          <option value="">Any Make</option>
          {MAKES.map(m => <option key={m} value={m}>{m}</option>)}
        </select>

        <input placeholder="Model" value={filters.model} onChange={handleChange('model')}
          className="border rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none" />

        <select value={filters.year} onChange={handleChange('year')}
          className="border rounded-lg px-3 py-2 text-sm text-gray-700 focus:ring-2 focus:ring-blue-500 outline-none">
          <option value="">Any Year</option>
          {YEARS.map(y => <option key={y} value={y}>{y}</option>)}
        </select>

        <input type="number" placeholder="Max Price ($)" value={filters.priceMax} onChange={handleChange('priceMax')}
          className="border rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none" />

        <button onClick={() => onSearch(filters)}
          className="bg-blue-600 text-white rounded-lg px-4 py-2 text-sm font-semibold hover:bg-blue-700 transition-colors">
          Search
        </button>
      </div>
    </div>
  );
}

export default SearchFilters;
