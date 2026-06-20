import { useState, useEffect } from 'react';
import Head from 'next/head';
import CarCard from '../components/CarCard';
import SearchFilters from '../components/SearchFilters';
import ContactForm from '../components/ContactForm';
import HeroSection from '../components/HeroSection';

export default function Home({ initialCars }) {
  const [cars, setCars] = useState(initialCars || []);
  const [loading, setLoading] = useState(false);
  const [filters, setFilters] = useState({ make: '', model: '', year: '', priceMax: '' });

  const handleSearch = async (newFilters) => {
    setLoading(true);
    try {
      const params = new URLSearchParams(
        Object.fromEntries(Object.entries(newFilters).filter(([, v]) => v !== ''))
      );
      const res = await fetch(`/api/cars?${params}`);
      const data = await res.json();
      setCars(data.cars || []);
    } catch (err) {
      console.error('Search failed:', err);
    } finally {
      setLoading(false);
    }
  };

  return (
    <>
      <Head>
        <title>Premier Auto – Find Your Perfect Car</title>
        <meta name="description" content="Browse our curated inventory of quality pre-owned and new vehicles." />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <link rel="icon" href="/favicon.ico" />
      </Head>

      <main className="min-h-screen bg-gray-50">
        <HeroSection />

        <section id="inventory" className="max-w-7xl mx-auto px-4 py-12">
          <h2 className="text-3xl font-bold text-gray-900 mb-6">Browse Inventory</h2>
          <SearchFilters filters={filters} setFilters={setFilters} onSearch={handleSearch} />

          {loading ? (
            <div className="flex justify-center items-center h-64">
              <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600" />
            </div>
          ) : (
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6 mt-8">
              {cars.length > 0 ? (
                cars.map((car) => <CarCard key={car.id} car={car} />)
              ) : (
                <p className="col-span-full text-center text-gray-500 py-16">
                  No vehicles match your criteria. Try adjusting your filters.
                </p>
              )}
            </div>
          )}
        </section>

        <section id="contact" className="bg-blue-900 py-16">
          <div className="max-w-3xl mx-auto px-4">
            <h2 className="text-3xl font-bold text-white mb-2 text-center">Get in Touch</h2>
            <p className="text-blue-200 text-center mb-8">
              Have a question or want to schedule a test drive? We're here to help.
            </p>
            <ContactForm />
          </div>
        </section>
      </main>
    </>
  );
}

// SSR for fast initial load & SEO
export async function getServerSideProps() {
  try {
    const res = await fetch(
      `${process.env.BACKEND_URL}/api/cars?limit=12`,
      { headers: { 'x-internal': '1' }, signal: AbortSignal.timeout(3000) }
    );
    const data = await res.json();
    return { props: { initialCars: data.cars || [] } };
  } catch {
    return { props: { initialCars: [] } };
  }
}
