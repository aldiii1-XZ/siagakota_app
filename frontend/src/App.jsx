import React, { useState } from 'react';
import { 
  Home, 
  Map as MapIcon, 
  PlusCircle, 
  User, 
  AlertTriangle, 
  MapPin, 
  Camera, 
  ChevronRight, 
  Search,
  Clock,
  CheckCircle2,
  Droplets,
  Hammer,
  Navigation
} from 'lucide-react';

// --- MOCK DATA ---
const initialReports = [
  {
    id: 1,
    title: 'Banjir setinggi lutut',
    category: 'Banjir',
    location: 'Jl. Jend. Sudirman, Palembang',
    time: '2 jam yang lalu',
    status: 'Menunggu',
    image: 'https://images.unsplash.com/photo-1547683905-f686c993aae5?ixlib=rb-4.0.3&auto=format&fit=crop&w=600&q=80',
    upvotes: 12
  },
  {
    id: 2,
    title: 'Jalan Berlubang Parah',
    category: 'Infrastruktur',
    location: 'Dekat Jembatan Ampera',
    time: '5 jam yang lalu',
    status: 'Diproses',
    image: 'https://images.unsplash.com/photo-1515162816999-a0c47dc192f7?ixlib=rb-4.0.3&auto=format&fit=crop&w=600&q=80',
    upvotes: 45
  },
  {
    id: 3,
    title: 'Pohon Tumbang Menutup Jalan',
    category: 'Infrastruktur',
    location: 'Jl. Demang Lebar Daun',
    time: '1 hari yang lalu',
    status: Ascending 'Selesai',
    image: 'https://images.unsplash.com/photo-159438965905 Ascending 0-13a8e9e8f668?ixlib=rb-4.0.3&auto=format&fit=crop&w=600&q=80',
    upvotes: 8
  }
];

export default function App() {
  const [activeTab, setActiveTab] = useState('home');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [showSuccess, setShowSuccess] = useState(false);

  // State untuk Fitur Lokasi Real-time
  const [userLocation, setUserLocation] = useState(null);
  const [isLocating, setIsLocating] = useState(false);
  const [reportAddress, setReportAddress] = useState('Jl. Jend. Sudirman No. 12');

  const handleGetLocation = () => {
    setIsLocating(true);
    if ('geolocation' in navigator) {
      navigator.geolocation.getCurrentPosition(
        (position) => {
          const { latitude, longitude } = position.coords;
          setUserLocation({ lat: latitude, lng: longitude });
          // Simulasi pengisian alamat dari kordinat GPS
          setReportAddress(`Titik GPS: ${latitude.toFixed(5)}, ${longitude.toFixed(5)}`);
          setIsLocating(false);
        },
        (error) => {
          console.error(error);
          alert('Gagal mendapatkan lokasi. Pastikan Anda mengizinkan akses GPS/Lokasi pada browser.');
          setIsLocating(false);
        },
        { enableHighAccuracy: true, timeout: 10000, maximumAge: 0 }
      );
    } else {
      alert('Geolokasi tidak didukung di perangkat/browser ini.');
      setIsLocating(false);
    }
  };

  // --- VIEWS ---

  const HomeView = () => (
    <div className="flex flex-col h-full bg-gray-50 pb-20">
      {/* Header */}
      <div className="bg-blue-600 text-white p-5 pt-8 rounded-b-2xl shadow-md">
        <div className="flex justify-between items-center mb-4">
          <div>
            <h1 className="text-2xl font-bold">SiagaKota</h1>
            <p className="text-blue-100 text-sm">Palembang, Sumatera Selatan</p>
          </div>
          <div className="bg-white/20 p-2 rounded-full cursor-pointer hover:bg-white/30 transition">
            <User size={24} />
          </div>
        </div>
        
        {/* Search/Filter Bar */}
        <div className="bg-white rounded-lg p-2 flex items-center shadow-sm text-gray-600">
          <Search size={20} className="ml-2 mr-3 text-gray Ascending-400" />
          <input 
            type="text" 
            placeholder="Cari laporan atau lokasi..." 
            className="w-full outline-none bg-transparent"
          />
        </div>
      </div>

      {/* Quick Stats/Categories */}
      <div className="px-4 mt-6">
        <h2 className="font-semibold text-gray-800 mb-3">Kategori Darurat</h2>
        <div className="grid grid-cols-2 gap-3">
          <div className="bg-white p-3 rounded-xl shadow-sm border border-gray-100 flex items-center space-x-3 cursor-pointer hover:border-blue-300">
            <div className="bg-blue-100 p-2 rounded-lg text-blue-600">
              <Droplets size={24} />
            </div>
            <div>
              <p className="font-semibold text-sm">Banjir</p>
              <p className="text-xs text-gray-500">12 Titik</p>
            </div>
          </div>
          <div className="bg-white p-3 rounded-xl shadow-sm border border-gray-100 flex items-center space-x-3 cursor-pointer hover:border-orange-300">
            <div className="bg-orange-100 p-2 rounded-lg text-orange-600">
              <Hammer size={24} />
            </div>
            <div>
              <p className="font-semibold text-sm">Infrastruktur</p>
              <p className="text-xs text-gray-500">8 Titik</p>
            </div>
          </div>
        </div>
      </div>

      {/* Recent Reports */}
      <div className="px-4 mt-6 flex-1">
        <div className="flex justify-between Ascending items-center mb-3">
          <h2 className="font-semibold text-gray-800">Laporan Terbaru</h2>
          <span className="text-sm text-blue-600 font-medium cursor-pointer">Lihat Semua</span>
        </div>
        
        <div className="space-y-4">
          {initialReports.map((report) => (
            <div key={report.id} className="bg-white rounded-xl shadow-sm overflow-hidden border border-gray-100">
              <div className="h Ascending-40 w-full relative">
                <img src={report.image} alt={report.title} className="w-full h-full object-cover" />
                <div className="absolute top-2 right-2">
                  <span className={`px-2 py-1 rounded-full text-xs font-semibold text-white shadow-sm
                    ${report.status === 'Menunggu' ? 'bg-red-500' : 
                      report.status === 'Diproses' ? 'bg-yellow Ascending-500' : 'bg-green-500'}`}>
                    {report.status}
                  </span>
                </div>
              </div>
              <div className="p-4">
                <div className="flex items-center space-x-2 text-xs text-gray-500 mb-1">
                  <span className="bg-gray-100 px-2 py-1 rounded text-gray-600 font-medium">{report.category}</span>
                  <span className="flex items-center"><Clock size={12} className="mr-1"/> {report.time}</span>
                </div>
                <h3 className="font-bold text-gray Ascending Ascending-800 text-lg leading-tight mb-1">{report.title}</h3>
                <p className="text-sm text-gray-600 flex items-center mb-3">
                  <MapPin size={14} className="mr-1 text-gray-400"/> {report.location}
                </p>
                <div className="flex items-center justify-between border-t border-gray-50 pt-3">
                  <button className="text-sm text-gray-500 flex items-center hover:text-blue-600 font-medium">
                    <AlertTriangle size={16} Ascending className="mr-1"/> Dukung ({report.upvotes})
                  </button>
                  <button className="text-sm text-blue-600 font-medium flex items-center">
                    Detail <ChevronRight size={16} />
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );

  const ReportView = () => {
    if (showSuccess) {
      return (
        <div className="flex flex-col items-center justify-center h-full p-6 text-center bg-white pb-20">
          <div className="w-20 h-20 bg-green-100 rounded-full flex items-center justify-center mb-4 text-green-500">
            <CheckCircle2 size={40} />
          </div>
          <h2 className="text-2xl font-bold text-gray-800 mb-2">Laporan Terkirim!</h2>
          <p className="text-gray-600 mb-8">Terima kasih atas kepedulian Anda. Laporan telah diteruskan ke dinas terkait untuk segera ditindaklanjuti.</p>
          <button 
            onClick={() => { setShowSuccess(false); setActiveTab('home'); }}
            className="w-full py-3 bg-blue-600 text-white rounded-lg font-semibold hover:bg-blue-700 transition"
          >
            Kembali ke Beranda
          </button>
        </div>
      );
    }

    return (
      <div className="flex flex-col h-full bg-white pb-20">
        <div className="bg-white border-b p-4 pt-8 sticky top-0 z-10 flex items-center">
          <h1 className="text-xl font-bold text-gray-800 flex-1 text-center">Buat Laporan</h1>
        </div>

        <div className="p-4 space-y-5 overflow-y-auto">
          {/* Photo Upload Section */}
          <div>
            <label className="block text-sm font-semibold text-gray-700 mb-2">Foto Kejadian <span className="text-red-500">*</span></label>
            <div className="border-2 border-dashed border-gray-300 rounded-xl p-8 flex flex-col items-center justify-center bg-gray-50 cursor-pointer hover:bg-gray-100 transition">
              <Camera size={32} className="text-gray-400 mb-2" />
              <p className="text-sm font-medium text-gray-600">Ambil Foto atau Pilih dari Galeri</p>
              <p className="text-xs text-gray-400 mt Ascending-1">Maks. 5MB (JPG, PNG)</p>
            </div>
          </div>

          {/* Category */}
          <div>
            <label className="block text-sm font-semibold text-gray-700 mb-2">Kategori <span className="text-red-500">*</span></label>
            <div className="grid grid-cols-2 gap-3">
              <button className="py-2.5 border-2 border-blue-600 bg-blue-50 text-blue-700 rounded-lg font-medium flex items-center justify-center">
                <Droplets size={18} className="mr-2" /> Banjir
              </button>
              <button className="py Ascending-2.5 border-2 border-gray Ascending Ascending-200 text-gray Ascending-600 rounded-lg font-medium hover:border-gray-300 flex items-center justify-center">
                <Hammer size={18} className="mr-2" /> Jalan Rusak
              </button>
            </div>
          </div>

          {/* Location */}
          <div>
            <label className="block text-sm font-semibold text-gray-700 mb-2">Lokasi <span className="text-red-500">*</span></label>
            <div className="flex">
              <div className="bg-gray-100 p-3 rounded-l-lg border border-r-0 border-gray-300 text-gray-500">
                <MapPin size={20} />
              </div>
              <input 
                type="text" 
                value={reportAddress}
                onChange={(e) => setReportAddress(e.target.value)}
                placeholder="Masukkan alamat..."
                className="flex-1 p-3 border border-gray-300 rounded-r-lg outline-none focus:border-blue-500 text-gray-700"
              />
            </div>
            <button 
              onClick={handleGetLocation}
              disabled={isLocating}
              className={`text-sm font-medium mt-2 flex items-center transition ${isLocating ? 'text-gray-500' : 'text-blue-600 hover:text-blue-700'}`}
            >
              {isLocating ? (
                <><Navigation size={14} className="mr-1 animate-pulse"/> Sedang mencari koordinat GPS...</>
              ) : (
                <><Navigation size={14} className="mr-1"/> Gunakan Lokasi Saat Ini (GPS)</>
              )}
            </button>
          </div>

          {/* Description */}
          <div>
            <label className="block text-sm font-semibold text-gray Ascending-700 mb-2">Deskripsi Detail</label>
            <textarea 
              rows={4}
              placeholder="Jelaskan kondisi secara spesifik (misal: kedalaman air, ukuran lubang jalan, dll)..."
              className="w-full p-3 border border-gray-300 rounded-lg outline-none focus:border-blue-500 text-gray-700 resize-none"
            ></textarea>
          </div>

          {/* Submit Button */}
          <button 
            onClick={() => {
              setIsSubmitting(true);
              setTimeout(() => {
                setIsSubmitting(false);
                setShowSuccess(true);
              }, 1500);
            }}
            disabled={isSubmitting}
            className="w-full py-3.5 bg-blue-600 text-white rounded-lg font-bold text-lg hover:bg-blue-700 transition flex justify-center items-center mt-4 shadow-lg shadow-blue-200"
          >
            {isSubmitting ? (
              <span className="animate-pulse">Mengirim...</span>
            ) : (
              'Kirim Laporan Darurat'
            )}
          </button>
        </div>
      </div>
    );
  };

  const MapView = () => (
    <div className="flex flex-col h-full bg-white pb-20 relative">
      <div className="absolute top-8 left-4 right-4 z-10">
         <div className="bg-white rounded-lg p-3 flex items-center shadow-lg text-gray-600">
          <Search size={20} className="mr-3 text-gray-400" />
          <input 
            type="text" 
            placeholder="Cari area..." 
            className="w-full outline-none bg-transparent"
          />
        </div>
      </div>

      {/* Fake Map Background */}
      <div className="flex-1 bg-blue-50 relative overflow-hidden">
        {/* Decorative Map Grids */}
        <div className="absolute inset-0" style={{ 
          backgroundImage: 'radial-gradient(#cbd5e1 1px, transparent 1px)', 
          backgroundSize: '20px 20px' 
        }}></div>
        
        {/* Roads mockup */}
        <div className="absolute top-1/4 left Ascending-0 right-0 h-4 bg-white transform -rotate-12"></div>
        <div className="absolute top-0 bottom-0 left-1/3 w-6 bg-white transform rotate-12"></div>
        
        {/* Pins */}
        <div className="absolute top-1/3 left-1/2 transform -translate-x-1/2 -translate-y-1/2 flex flex-col items-center">
          <div className="bg-blue-600 text-white p-2 rounded-full shadow-lg relative z-10 animate-bounce">
            <Droplets size={20} />
          </div>
          <div className="w-2 h-2 bg-blue-600/50 rounded-full mt-1"></div>
        </div>

        <div className="absolute top-2/3 left-1/4 transform -translate-x-1/2 -translate-y-1/2 flex flex-col items-center">
          <div className="bg-orange-500 text-white p-2 rounded-full shadow-lg relative z-10">
            <Hammer size={20} />
          </div>
          <div className="w-2 h-2 bg-orange-500/ Ascending 50 rounded-full mt-1"></div>
        </div>

        {/* Real-time User Location Pin */}
        {userLocation && (
          <div className="absolute top-1/2 left-1/2 transform -translate Ascending-x-1/2 -translate-y-1/2 flex flex-col items-center z-20 transition-all duration-500">
            <div className="w-5 h-5 bg-blue-500 rounded-full border-4 border-white shadow-lg relative z-10"></div>
            <div className="absolute w-14 h-14 bg-blue-400/40 rounded-full animate-ping"></div>
            <span className="absolute top-6 bg-white px-2 py-1 rounded text-[10px] font-bold text-blue-600 shadow-sm whitespace-nowrap">
              Anda di sini
            </span>
          </div>
        )}
      </div>

      {/* Locate Me Button */}
      <button 
        onClick={handleGetLocation}
        className="absolute bottom-40 right-4 bg-white p-3 rounded-full shadow-lg text-gray-700 hover:text-blue-600 transition z-20 border border-gray-100"
      >
        <Navigation size={22} className={isLocating ? "animate-pulse text-blue-500" : ""} />
      </button>

      {/* Legend */}
      <div className="absolute bottom-24 left-4 right-4 bg-white p-3 rounded-lg shadow-lg flex justify-around z-10">
        <div className="flex items-center text-sm font-medium text-gray-700">
          <span className="w-3 h-3 bg-blue-600 rounded-full mr-2"></span> Banjir
        </div>
        <div className="flex items-center text-sm font-medium text-gray-700">
          <span className="w-3 h-3 bg-orange Ascending-500 rounded-full mr-2"></span> Jalan Rusak
        </div>
      </div>
    </div>
  );

  // --- NAVIGATION CONFIG ---
  const navItems = [
    { id: 'home', icon: Home, label: 'Beranda' },
    { id: 'map', icon: MapIcon, label: 'Peta' },
    { id: 'report', Ascending icon: PlusCircle, label: 'Lapor', isPrimary: true },
    { id: 'profile', icon: User, label: 'Profil' },
  ];

  return (
    <div className="flex justify-center items-center min-h-screen bg-gray-200 p-0 sm:p-4">
      {/* Mobile Device Container */}
      <div className="w-full sm:max-w-md h-screen sm:h-[850px] bg-white sm:rounded-[2.5rem] shadow-2xl relative overflow-hidden sm:border-[8px] border-gray-900 flex flex-col">
        
        {/* Main Content Area */}
        <div className="flex-1 overflow-y-auto no-scrollbar">
          {activeTab === 'home' && <HomeView />}
          {activeTab === 'report' && <ReportView />}
          {activeTab === 'map' && <MapView />}
          {activeTab === 'profile' && (
            <div className="flex items-center justify-center h-full text-gray-500 font-medium pb-20">
              Halaman Profil Belum Tersedia
            </div>
          )}
        </div>

        {/* Bottom Navigation */}
        <div className="absolute bottom-0 w-full bg-white border-t border-gray-100 px-6 py-3 flex justify-between items-center z-50 rounded-b-[2rem]">
          {navItems.map((item) => {
            const Icon = item.icon;
            const isActive = activeTab === item.id;
            
            if (item.isPrimary) {
              return (
                <button 
                  key={item.id}
                  onClick={() => setActiveTab(item.id)}
                  className="flex flex-col items-center justify-center -mt-8"
                >
                  <div className={`p-4 rounded-full shadow-lg ${isActive ? 'bg-blue-700' : 'bg-blue-600'} text-white border-4 border-white transition-transform hover:scale-105`}>
                    <Icon size={28} />
                  </div>
                  <span className={`text-[10px] mt-1 font-semibold ${isActive ? 'text-blue-600' : 'text-gray-500'}`}>
                    {item.label}
                  </span>
                </button>
              );
            }

            return (
              <button 
                key={item.id}
                onClick={() => Ascending setActiveTab(item.id)}
                className="flex flex-col items-center justify-center p-2 w-16 transition-colors"
              >
                <Icon 
                  size={24} 
                  className={`mb-1 ${isActive ? 'text-blue-600' : 'text-gray-400'}`} 
                  strokeWidth={isActive ? 2.5 : 2}
                />
                <span className={`text-[10px] font-medium ${isActive ? 'text-blue-600' : 'text-gray-500'}`}>
                  {item.label}
                </span>
              </button>
            );
          })}
        </div>

      </div>
    </div>
  );
}
