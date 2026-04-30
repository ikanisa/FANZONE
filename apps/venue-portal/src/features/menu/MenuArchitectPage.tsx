import React, { useState } from 'react';
import { 
  Plus, 
  Search, 
  Filter, 
  MoreVertical, 
  Edit3, 
  Trash2, 
  EyeOff,
  GripVertical,
  Wand2
} from 'lucide-react';
import { Reorder } from 'framer-motion';
import { MenuMagicModal } from '../../components/MenuMagicModal';
import { ScannedMenuItem } from '../../hooks/useMenuMagic';

export const MenuArchitectPage: React.FC = () => {
  const [isMagicModalOpen, setIsMagicModalOpen] = useState(false);
  const [categories, setCategories] = useState([
    { id: '1', name: 'Signature Burgers', itemCount: 8, isActive: true },
    { id: '2', name: 'Starters & Wings', itemCount: 12, isActive: true },
    { id: '3', name: 'Draft Beers', itemCount: 6, isActive: true },
    { id: '4', name: 'Cocktails', itemCount: 15, isActive: false },
  ]);

  const handleMagicImport = (items: ScannedMenuItem[]) => {
    console.log('Importing items to DB:', items);
    // Real logic would group items by category and perform bulk insert via Supabase
    alert(`Successfully imported ${items.length} items from your photo!`);
  };

  return (
    <div className="max-w-7xl mx-auto space-y-8">
      <div className="flex justify-between items-start">
        <div>
          <h1 className="text-4xl font-black tracking-tighter">Menu Architect</h1>
          <p className="text-textSecondary font-medium mt-1">Design and manage your digital ordering experience.</p>
        </div>
        <div className="flex gap-3">
          <button 
            onClick={() => setIsMagicModalOpen(true)}
            className="flex items-center gap-2 px-6 py-3 bg-accent/10 text-success rounded-xl font-bold hover:bg-accent/20 transition-all"
          >
            <Wand2 size={18} />
            MAGIC IMPORT
          </button>
          <button className="flex items-center gap-2 px-6 py-3 bg-primary text-primaryText rounded-xl font-bold hover:opacity-90 active:scale-95 transition-all">
            <Plus size={18} />
            ADD CATEGORY
          </button>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-8">
        {/* Categories Sidebar */}
        <div className="lg:col-span-4 space-y-4">
           <div className="bg-white p-6 rounded-[32px] border border-border">
              <h3 className="font-black text-lg mb-4 px-2">Categories</h3>
              <Reorder.Group axis="y" values={categories} onReorder={setCategories} className="space-y-2">
                {categories.map((cat) => (
                  <Reorder.Item 
                    key={cat.id} 
                    value={cat}
                    className="group bg-surface2 hover:bg-surface3 border border-transparent hover:border-border p-4 rounded-2xl flex items-center gap-3 cursor-pointer transition-all"
                  >
                    <GripVertical size={16} className="text-textSecondary opacity-0 group-hover:opacity-100 transition-opacity" />
                    <div className="flex-1">
                      <p className="font-bold text-sm">{cat.name}</p>
                      <p className="text-[10px] font-bold text-textSecondary uppercase">{cat.itemCount} Items</p>
                    </div>
                    {!cat.isActive && <EyeOff size={14} className="text-danger" />}
                    <button className="p-2 opacity-0 group-hover:opacity-100 hover:bg-white rounded-lg transition-all">
                      <MoreVertical size={14} />
                    </button>
                  </Reorder.Item>
                ))}
              </Reorder.Group>
           </div>
        </div>

        {/* Items Grid */}
        <div className="lg:col-span-8 space-y-6">
           <div className="bg-white p-4 rounded-2xl border border-border flex items-center gap-4">
              <div className="flex-1 relative">
                <Search size={18} className="absolute left-4 top-1/2 -translate-y-1/2 text-textSecondary" />
                <input 
                  type="text" 
                  placeholder="Search items in Signature Burgers..." 
                  className="w-full pl-12 pr-4 py-3 bg-surface2 border-transparent rounded-xl focus:bg-white focus:border-border transition-all text-sm outline-none"
                />
              </div>
              <button className="p-3 bg-surface2 rounded-xl text-textSecondary hover:bg-surface3 transition-colors">
                <Filter size={18} />
              </button>
           </div>

           <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {[1, 2, 3, 4, 5].map((i) => (
                <div key={i} className="bg-white p-4 rounded-3xl border border-border group hover:border-primary/20 hover:shadow-xl hover:shadow-primary/5 transition-all">
                   <div className="flex gap-4">
                      <div className="w-24 h-24 bg-surface2 rounded-2xl overflow-hidden shrink-0">
                         <img 
                           src={`https://images.unsplash.com/photo-1568901346375-23c9450c58cd?auto=format&fit=crop&q=60&w=200`} 
                           className="w-full h-full object-cover group-hover:scale-110 transition-transform duration-500" 
                           alt="Burger" 
                         />
                      </div>
                      <div className="flex-1 py-1">
                         <div className="flex justify-between items-start">
                            <h4 className="font-black text-lg">The Classic #{i}</h4>
                            <div className="flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                               <button className="p-2 hover:bg-surface2 rounded-lg text-textSecondary hover:text-text"><Edit3 size={14} /></button>
                               <button className="p-2 hover:bg-danger/10 rounded-lg text-textSecondary hover:text-danger"><Trash2 size={14} /></button>
                            </div>
                         </div>
                         <p className="text-xs text-textSecondary line-clamp-2 mt-1 font-medium">Double beef patty, cheddar, secret sauce, artisanal brioche bun.</p>
                         <div className="mt-3 flex items-center justify-between">
                            <span className="font-black text-primary">€12.50</span>
                            <div className="flex items-center gap-1 text-[10px] font-black text-success uppercase">
                               <div className="w-1.5 h-1.5 bg-success rounded-full" />
                               Available
                            </div>
                         </div>
                      </div>
                   </div>
                </div>
              ))}
              
              <button className="border-2 border-dashed border-border rounded-3xl p-8 flex flex-col items-center justify-center gap-3 text-textSecondary hover:border-primary hover:text-primary transition-all group min-h-[128px]">
                 <div className="w-12 h-12 rounded-full bg-surface2 flex items-center justify-center group-hover:bg-primary/5 transition-colors">
                    <Plus size={24} />
                 </div>
                 <span className="font-bold text-sm uppercase tracking-widest">Add New Item</span>
              </button>
           </div>
        </div>
      </div>

      <MenuMagicModal 
        isOpen={isMagicModalOpen} 
        onClose={() => setIsMagicModalOpen(false)}
        onComplete={handleMagicImport}
      />
    </div>
  );
};
