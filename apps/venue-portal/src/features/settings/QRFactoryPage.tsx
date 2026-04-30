import React, { useState } from 'react';
import { 
  QrCode, 
  Download, 
  Plus, 
  Trash2, 
  Settings2, 
  Printer,
  ChevronRight,
  Maximize2
} from 'lucide-react';
import { motion } from 'framer-motion';

interface QRTable {
  id: string;
  tableNumber: string;
  url: string;
}

export const QRFactoryPage: React.FC = () => {
  const [venueSlug] = useState('stadium-sports-bar');
  const [startRange, setStartRange] = useState('1');
  const [endRange, setEndRange] = useState('10');
  const [tables, setTables] = useState<QRTable[]>([]);
  const [isGenerating, setIsGenerating] = useState(false);

  const generateRange = () => {
    setIsGenerating(true);
    const start = parseInt(startRange);
    const end = parseInt(endRange);
    
    const newTables: QRTable[] = [];
    for (let i = start; i <= end; i++) {
      const tableNum = i.toString();
      newTables.push({
        id: Math.random().toString(36).substring(7),
        tableNumber: tableNum,
        url: `https://fanzone.app/v/${venueSlug}?t=${tableNum}`
      });
    }

    setTimeout(() => {
      setTables(newTables);
      setIsGenerating(false);
    }, 800);
  };

  const getQRUrl = (data: string) => {
    return `https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${encodeURIComponent(data)}&bgcolor=FFFFFF&color=000000&margin=10`;
  };

  return (
    <div className="max-w-7xl mx-auto space-y-8">
      <div className="flex justify-between items-start">
        <div>
          <h1 className="text-4xl font-black tracking-tighter">QR Factory</h1>
          <p className="text-textSecondary font-medium mt-1">Generate and manage branded QR codes for your tables.</p>
        </div>
        <div className="flex gap-3">
          <button className="flex items-center gap-2 px-6 py-3 bg-white border border-border rounded-xl font-bold hover:bg-surface2 transition-all">
            <Printer size={18} />
            PRINT ALL
          </button>
          <button className="flex items-center gap-2 px-6 py-3 bg-primary text-primaryText rounded-xl font-bold hover:opacity-90 active:scale-95 transition-all">
            <Download size={18} />
            DOWNLOAD BATCH
          </button>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-8">
        {/* Controls Sidebar */}
        <div className="lg:col-span-4 space-y-6">
           <div className="bg-white p-8 rounded-[32px] border border-border shadow-sm">
              <div className="flex items-center gap-3 mb-6">
                 <div className="w-10 h-10 bg-primary/5 text-primary rounded-xl flex items-center justify-center">
                    <Settings2 size={20} />
                 </div>
                 <h3 className="font-black text-xl">Generator</h3>
              </div>

              <div className="space-y-4">
                 <div>
                    <label className="text-xs font-bold text-textSecondary uppercase tracking-widest mb-2 block">Table Range</label>
                    <div className="flex items-center gap-3">
                       <input 
                         type="number" 
                         value={startRange}
                         onChange={(e) => setStartRange(e.target.value)}
                         placeholder="1"
                         className="w-full bg-surface2 border border-border rounded-xl px-4 py-3 focus:bg-white transition-all outline-none font-bold"
                       />
                       <span className="text-textSecondary">to</span>
                       <input 
                         type="number" 
                         value={endRange}
                         onChange={(e) => setEndRange(e.target.value)}
                         placeholder="10"
                         className="w-full bg-surface2 border border-border rounded-xl px-4 py-3 focus:bg-white transition-all outline-none font-bold"
                       />
                    </div>
                 </div>

                 <div className="pt-4">
                    <button 
                      onClick={generateRange}
                      disabled={isGenerating}
                      className="w-full h-14 bg-primary text-primaryText font-black rounded-2xl flex items-center justify-center gap-2 hover:opacity-90 active:scale-95 transition-all disabled:opacity-50"
                    >
                       {isGenerating ? 'GENERATING...' : (
                         <>
                           <QrCode size={20} />
                           GENERATE CODES
                         </>
                       )}
                    </button>
                 </div>
              </div>
           </div>

           <div className="bg-accent/10 p-8 rounded-[32px] border border-accent/20">
              <h4 className="font-black text-lg mb-2">Pro Tip</h4>
              <p className="text-sm text-text font-medium opacity-80 leading-relaxed">
                Download your batch as a ZIP and send them to your local printer for high-quality table stickers.
              </p>
           </div>
        </div>

        {/* Preview Grid */}
        <div className="lg:col-span-8">
           {tables.length === 0 ? (
             <div className="bg-white border-2 border-dashed border-border rounded-[40px] h-[500px] flex flex-col items-center justify-center text-center p-12">
                <div className="w-20 h-20 bg-surface2 rounded-full flex items-center justify-center text-textSecondary mb-6">
                   <QrCode size={40} />
                </div>
                <h3 className="text-2xl font-black mb-2">No QR Codes Generated</h3>
                <p className="text-textSecondary max-w-sm">Enter a table range on the left to start generating your branded ordering codes.</p>
             </div>
           ) : (
             <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                {tables.map((table) => (
                  <motion.div 
                    initial={{ opacity: 0, y: 20 }}
                    animate={{ opacity: 1, y: 0 }}
                    key={table.id} 
                    className="bg-white p-8 rounded-[32px] border border-border group hover:border-primary/20 transition-all relative overflow-hidden"
                  >
                     <div className="flex justify-between items-start mb-6">
                        <div>
                           <p className="text-[10px] font-bold text-textSecondary uppercase tracking-widest">Table</p>
                           <h4 className="text-4xl font-black">{table.tableNumber}</h4>
                        </div>
                        <div className="flex gap-2">
                           <button className="p-2 hover:bg-surface2 rounded-lg transition-colors"><Download size={18} /></button>
                           <button className="p-2 hover:bg-surface2 rounded-lg transition-colors"><Maximize2 size={18} /></button>
                        </div>
                     </div>

                     <div className="aspect-square bg-white border border-border rounded-2xl flex items-center justify-center p-4 relative group-hover:shadow-2xl group-hover:shadow-primary/5 transition-all">
                        <img src={getQRUrl(table.url)} className="w-full h-full object-contain" alt={`QR Code for Table ${table.tableNumber}`} />
                        <div className="absolute inset-0 bg-primary/80 opacity-0 group-hover:opacity-100 flex items-center justify-center transition-opacity rounded-2xl">
                           <span className="text-primaryText font-black text-sm tracking-widest uppercase">Preview Mode</span>
                        </div>
                     </div>

                     <div className="mt-6 flex flex-col items-center gap-2">
                        <p className="text-[10px] font-black text-textSecondary uppercase tracking-[0.2em]">Scan to order</p>
                        <div className="w-12 h-1 bg-accent rounded-full" />
                        <p className="text-[9px] text-textSecondary opacity-50 truncate w-full text-center mt-2">{table.url}</p>
                     </div>
                  </motion.div>
                ))}
             </div>
           )}
        </div>
      </div>
    </div>
  );
};
