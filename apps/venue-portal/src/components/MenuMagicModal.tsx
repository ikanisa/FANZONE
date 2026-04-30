import React, { useState, useRef } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { 
  X, 
  Wand2, 
  Upload, 
  Loader2, 
  CheckCircle2, 
  AlertCircle,
  Plus
} from 'lucide-react';
import { useMenuMagic, ScannedMenuItem } from '../hooks/useMenuMagic';

interface MenuMagicModalProps {
  isOpen: boolean;
  onClose: () => void;
  onComplete: (items: ScannedMenuItem[]) => void;
}

export const MenuMagicModal: React.FC<MenuMagicModalProps> = ({ isOpen, onClose, onComplete }) => {
  const { scanMenu, loading, error } = useMenuMagic();
  const [scannedItems, setScannedItems] = useState<ScannedMenuItem[]>([]);
  const [step, setStep] = useState<'upload' | 'scanning' | 'review'>('upload');
  const fileInputRef = useRef<HTMLInputElement>(null);

  const handleFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    setStep('scanning');
    const items = await scanMenu(file);
    
    if (items.length > 0) {
      setScannedItems(items);
      setStep('review');
    } else {
      setStep('upload');
    }
  };

  const handleConfirm = () => {
    onComplete(scannedItems);
    onClose();
  };

  if (!isOpen) return null;

  return (
    <AnimatePresence>
      <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
        <motion.div 
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          onClick={onClose}
          className="absolute inset-0 bg-black/60 backdrop-blur-sm"
        />
        
        <motion.div 
          initial={{ scale: 0.9, opacity: 0, y: 20 }}
          animate={{ scale: 1, opacity: 1, y: 0 }}
          exit={{ scale: 0.9, opacity: 0, y: 20 }}
          className="relative w-full max-w-2xl bg-white rounded-[40px] shadow-2xl overflow-hidden"
        >
          <div className="p-8 border-b border-border flex justify-between items-center">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 bg-primary/5 text-primary rounded-xl flex items-center justify-center">
                <Wand2 size={20} />
              </div>
              <h2 className="text-2xl font-black tracking-tight">Menu Magic</h2>
            </div>
            <button onClick={onClose} className="p-2 hover:bg-surface2 rounded-full transition-colors text-textSecondary"><X size={20} /></button>
          </div>

          <div className="p-8 max-h-[60vh] overflow-y-auto no-scrollbar">
            {step === 'upload' && (
              <div className="text-center py-12">
                <div 
                  onClick={() => fileInputRef.current?.click()}
                  className="w-full border-2 border-dashed border-border rounded-[32px] p-12 hover:border-primary hover:bg-primary/5 transition-all cursor-pointer group"
                >
                  <div className="w-16 h-16 bg-surface2 rounded-full flex items-center justify-center mx-auto mb-6 group-hover:scale-110 transition-transform">
                    <Upload size={32} className="text-textSecondary group-hover:text-primary" />
                  </div>
                  <h3 className="text-xl font-bold mb-2">Upload Menu Photo</h3>
                  <p className="text-textSecondary max-w-xs mx-auto">Snap a clear photo of your physical menu and our AI will extract every item instantly.</p>
                  <input 
                    type="file" 
                    ref={fileInputRef}
                    onChange={handleFileChange}
                    accept="image/*"
                    className="hidden" 
                  />
                </div>
                {error && (
                  <div className="mt-6 p-4 bg-danger/10 text-danger rounded-2xl flex items-center gap-3">
                    <AlertCircle size={18} />
                    <span className="text-sm font-bold">{error}</span>
                  </div>
                )}
              </div>
            )}

            {step === 'scanning' && (
              <div className="text-center py-20">
                <motion.div 
                  animate={{ rotate: 360 }}
                  transition={{ duration: 2, repeat: Infinity, ease: "linear" }}
                  className="w-20 h-20 border-4 border-primary/10 border-t-primary rounded-full mx-auto mb-8"
                />
                <h3 className="text-2xl font-black mb-2 animate-pulse">Digitizing Menu...</h3>
                <p className="text-textSecondary">Gemini AI is analyzing your items and prices.</p>
              </div>
            )}

            {step === 'review' && (
              <div className="space-y-4">
                <div className="flex items-center justify-between mb-6">
                  <span className="text-sm font-bold text-textSecondary uppercase tracking-widest">Extracted {scannedItems.length} Items</span>
                  <button className="text-primary font-bold text-sm hover:underline flex items-center gap-1">
                    <Plus size={14} /> Add Manual
                  </button>
                </div>
                <div className="grid grid-cols-1 gap-3">
                  {scannedItems.map((item, i) => (
                    <div key={i} className="flex items-center justify-between p-4 bg-surface2 rounded-2xl border border-border">
                      <div>
                        <p className="font-bold">{item.name}</p>
                        <p className="text-xs text-textSecondary">{item.category || 'Uncategorized'}</p>
                      </div>
                      <div className="flex items-center gap-4">
                        <span className="font-black text-primary">€{item.price.toFixed(2)}</span>
                        <CheckCircle2 size={18} className="text-success" />
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>

          {step === 'review' && (
            <div className="p-8 bg-surface2 border-t border-border flex gap-4">
              <button onClick={() => setStep('upload')} className="flex-1 h-14 bg-white border border-border font-bold rounded-2xl">RE-SCAN</button>
              <button 
                onClick={handleConfirm}
                className="flex-2 h-14 bg-primary text-primaryText font-black rounded-2xl shadow-xl shadow-primary/20"
              >
                IMPORT TO MENU
              </button>
            </div>
          )}
        </motion.div>
      </div>
    </AnimatePresence>
  );
};
