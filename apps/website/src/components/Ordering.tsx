import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { 
  Utensils, 
  ChevronRight, 
  Plus, 
  Minus, 
  ShoppingCart, 
  X, 
  Coins, 
  CreditCard, 
  Smartphone, 
  Banknote,
  CheckCircle2,
  Clock,
  AlertCircle
} from 'lucide-react';
import { useAppStore } from '../store/useAppStore';
import { api } from '../services/api';
import { Card } from './ui/Card';
import { Badge } from './ui/Badge';
import { FETDisplay } from './ui/FETDisplay';
import type {
  Venue,
  MenuItem,
  MenuCategory,
  PaymentMethod,
  Order,
  OrderStatus
} from '../types';

interface CartItem extends MenuItem {
  quantity: number;
}

export const Ordering: React.FC = () => {
  const { fetBalance, deductFet } = useAppStore();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [venue, setVenue] = useState<Venue | null>(null);
  const [categories, setCategories] = useState<MenuCategory[]>([]);
  const [items, setItems] = useState<MenuItem[]>([]);
  const [activeCategory, setActiveCategory] = useState<string | null>(null);
  const [cart, setCart] = useState<CartItem[]>([]);
  const [isCheckoutOpen, setIsCheckoutSheetOpen] = useState(false);
  const [orderStatus, setOrderStatus] = useState<'idle' | 'submitting' | 'success'>('idle');
  const [placedOrder, setPlacedOrder] = useState<Order | null>(null);
  const [useFet, setUseFet] = useState(false);

  // Extract slug from URL or default
  const venueSlug = window.location.pathname.split('/').pop() || 'stadium-sports-bar';
  const tableNumber = new URLSearchParams(window.location.search).get('t') || '12';

  useEffect(() => {
    const loadVenueData = async () => {
      try {
        setLoading(true);
        const v = await api.fetchVenueBySlug(venueSlug);
        if (!v) {
          setError('Venue not found');
          return;
        }
        setVenue(v);
        
        const { categories: cats, items: itms } = await api.fetchMenu(v.id);
        setCategories(cats);
        setItems(itms);
        if (cats.length > 0) {
          setActiveCategory(cats[0].id);
        }
      } catch (err) {
        console.error('Failed to load venue:', err);
        setError('Failed to connect to the venue system.');
      } finally {
        setLoading(false);
      }
    };

    loadVenueData();
  }, [venueSlug]);

  const subtotal = cart.reduce((sum, item) => sum + (item.price * item.quantity), 0);
  const fetDiscount = useFet ? Math.min(fetBalance / 100, subtotal) : 0;
  const total = Math.max(0, subtotal - fetDiscount);
  const totalItemCount = cart.reduce((sum, item) => sum + item.quantity, 0);

  const addToCart = (item: MenuItem) => {
    setCart(prev => {
      const existing = prev.find(i => i.id === item.id);
      if (existing) {
        return prev.map(i => i.id === item.id ? { ...i, quantity: i.quantity + 1 } : i);
      }
      return [...prev, { ...item, quantity: 1 }];
    });
  };

  const removeFromCart = (id: string) => {
    setCart(prev => {
      const existing = prev.find(i => i.id === id);
      if (existing && existing.quantity > 1) {
        return prev.map(i => i.id === id ? { ...i, quantity: i.quantity - 1 } : i);
      }
      return prev.filter(i => i.id !== id);
    });
  };

  const handlePlaceOrder = async () => {
    if (!venue) return;
    setOrderStatus('submitting');
    
    try {
      // Find table ID — in a real deep link flow we would resolve this
      // For now we assume a placeholder UUID or similar if table logic is needed
      const tableId = '00000000-0000-0000-0000-000000000000'; // Placeholder

      const order = await api.placeOrder({
        venueId: venue.id,
        tableId: tableId,
        paymentMethod: 'cash',
        items: cart.map(i => ({ menuItemId: i.id, quantity: i.quantity })),
        useFet: useFet
      });

      if (useFet) {
        deductFet(Math.floor(fetDiscount * 100));
      }

      setPlacedOrder(order);
      setOrderStatus('success');
      setCart([]);
    } catch (err) {
      console.error('Order failed:', err);
      alert('Failed to place order. Please try again.');
      setOrderStatus('idle');
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="w-12 h-12 border-4 border-primary border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  if (error || !venue) {
    return (
      <div className="flex flex-col items-center justify-center min-h-screen p-8 text-center">
        <AlertCircle size={48} className="text-danger mb-4" />
        <h2 className="text-2xl font-black mb-2">Oops!</h2>
        <p className="text-textSecondary mb-8">{error || 'Something went wrong.'}</p>
        <button onClick={() => window.location.reload()} className="px-8 py-3 bg-primary text-primaryText rounded-xl font-bold">RETRY</button>
      </div>
    );
  }

  if (orderStatus === 'success' && placedOrder) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[60vh] p-8 text-center">
        <motion.div 
          initial={{ scale: 0 }}
          animate={{ scale: 1 }}
          className="w-20 h-20 bg-success/20 text-success rounded-full flex items-center justify-center mb-6"
        >
          <CheckCircle2 size={48} />
        </motion.div>
        <h2 className="text-3xl font-black text-text mb-2">Order Placed!</h2>
        <p className="text-textSecondary mb-8">Order #{placedOrder.orderCode} has been sent to the kitchen.</p>
        
        <Card className="w-full max-w-sm p-6 mb-8 text-left bg-surface2 border-border">
          <div className="flex justify-between mb-4">
            <span className="text-textSecondary">Amount to Pay</span>
            <span className="font-bold text-text">€{placedOrder.totalAmount.toFixed(2)}</span>
          </div>
          {placedOrder.paymentFetAmount > 0 && (
            <div className="flex justify-between text-success">
              <span>Tokens Used</span>
              <span className="font-bold">{placedOrder.paymentFetAmount} FET</span>
            </div>
          )}
        </Card>

        <button 
          onClick={() => setOrderStatus('idle')}
          className="w-full max-w-sm h-14 bg-primary text-primaryText font-black rounded-2xl"
        >
          DONE
        </button>
      </div>
    );
  }

  return (
    <div className="relative min-h-screen pb-32">
      {/* Hero Header */}
      <div className="relative h-48 overflow-hidden">
        {venue.coverUrl && <img src={venue.coverUrl} className="w-full h-full object-cover" alt={venue.name} />}
        <div className="absolute inset-0 bg-gradient-to-t from-background to-transparent" />
        <div className="absolute bottom-4 left-6 right-6">
          <h1 className="text-3xl font-black text-text drop-shadow-lg">{venue.name}</h1>
          <div className="flex items-center gap-2 mt-1">
            <Badge variant={venue.isOpen ? "success" : "secondary"}>{venue.isOpen ? "OPEN NOW" : "CLOSED"}</Badge>
            <span className="text-sm text-textSecondary font-medium">Table {tableNumber}</span>
          </div>
        </div>
      </div>

      {/* Category Nav */}
      <div className="sticky top-0 z-10 bg-background/80 backdrop-blur-xl border-b border-border px-4 py-3 flex gap-2 overflow-x-auto no-scrollbar">
        {categories.map(cat => (
          <button
            key={cat.id}
            onClick={() => setActiveCategory(cat.id)}
            className={`px-4 py-2 rounded-full text-sm font-bold transition-all whitespace-nowrap ${
              activeCategory === cat.id 
                ? 'bg-primary text-primaryText' 
                : 'bg-surface2 text-textSecondary border border-border'
            }`}
          >
            {cat.name}
          </button>
        ))}
      </div>

      {/* Menu List */}
      <div className="p-6 space-y-6">
        {items.filter(i => i.categoryId === activeCategory).map(item => (
          <div key={item.id} className="flex gap-4 group">
            <div className="flex-1">
              <h3 className="text-lg font-bold text-text group-hover:text-primary transition-colors">{item.name}</h3>
              <p className="text-sm text-textSecondary line-clamp-2 mt-1">{item.description}</p>
              <div className="flex items-center gap-2 mt-3">
                <span className="text-lg font-black text-text">
                  {item.currencyCode === 'RWF' ? '' : '€'}{item.price.toLocaleString()} {item.currencyCode === 'RWF' ? 'RWF' : ''}
                </span>
              </div>
            </div>
            <div className="shrink-0 flex flex-col items-center gap-2">
              {cart.find(i => i.id === item.id) ? (
                <div className="flex items-center bg-surface2 rounded-xl border border-border overflow-hidden">
                  <button onClick={() => removeFromCart(item.id)} className="p-2 hover:bg-surface3 text-text"><Minus size={16} /></button>
                  <span className="w-8 text-center font-bold text-text">{cart.find(i => i.id === item.id)?.quantity}</span>
                  <button onClick={() => addToCart(item)} className="p-2 hover:bg-surface3 text-primary"><Plus size={16} /></button>
                </div>
              ) : (
                <button 
                  onClick={() => addToCart(item)}
                  className="w-10 h-10 bg-surface2 border border-border rounded-xl flex items-center justify-center text-text hover:bg-primary hover:text-primaryText hover:border-primary transition-all"
                >
                  <Plus size={20} />
                </button>
              )}
            </div>
          </div>
        ))}
      </div>

      {/* Persistent Cart Pill */}
      <AnimatePresence>
        {totalItemCount > 0 && (
          <motion.div 
            initial={{ y: 100 }}
            animate={{ y: 0 }}
            exit={{ y: 100 }}
            className="fixed bottom-24 left-6 right-6 z-20"
          >
            <button 
              onClick={() => setIsCheckoutSheetOpen(true)}
              className="w-full h-16 bg-text text-background rounded-full flex items-center px-6 shadow-2xl active:scale-95 transition-transform"
            >
              <div className="relative">
                <ShoppingCart size={24} />
                <span className="absolute -top-2 -right-2 w-5 h-5 bg-primary text-primaryText text-[10px] font-black rounded-full flex items-center justify-center border-2 border-text">
                  {totalItemCount}
                </span>
              </div>
              <span className="flex-1 text-center font-black text-sm tracking-wider uppercase">VIEW CART</span>
              <span className="font-black text-lg">
                {venue?.country === 'RW' ? '' : '€'}{total.toLocaleString()} {venue?.country === 'RW' ? 'RWF' : ''}
              </span>
            </button>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Checkout Sheet */}
      <AnimatePresence>
        {isCheckoutOpen && (
          <>
            <motion.div 
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              onClick={() => setIsCheckoutSheetOpen(false)}
              className="fixed inset-0 bg-background/80 backdrop-blur-sm z-30" 
            />
            <motion.div 
              initial={{ y: '100%' }}
              animate={{ y: 0 }}
              exit={{ y: '100%' }}
              className="fixed inset-x-0 bottom-0 max-h-[90vh] bg-surface1 rounded-t-[32px] border-t border-border z-40 overflow-y-auto no-scrollbar"
            >
              <div className="p-8">
                <div className="flex justify-between items-center mb-8">
                  <h2 className="text-2xl font-black text-text">Review Order</h2>
                  <button onClick={() => setIsCheckoutSheetOpen(false)} className="p-2 bg-surface2 rounded-full text-textSecondary hover:text-text"><X size={20} /></button>
                </div>

                <div className="space-y-4 mb-8">
                  {cart.map(item => (
                    <div key={item.id} className="flex justify-between items-center">
                      <div className="flex items-center gap-3">
                        <span className="font-bold text-text">{item.quantity}x</span>
                        <span className="text-textSecondary">{item.name}</span>
                      </div>
                      <span className="font-bold text-text">
                        {item.currencyCode === 'RWF' ? '' : '€'}{(item.price * item.quantity).toLocaleString()} {item.currencyCode === 'RWF' ? 'RWF' : ''}
                      </span>
                    </div>
                  ))}
                </div>

                {/* Gamification Integration */}
                <div className="bg-surface2 rounded-2xl border border-border p-4 mb-8">
                   <div className="flex items-center justify-between">
                     <div className="flex items-center gap-3">
                       <div className="w-10 h-10 bg-accent2/10 text-accent2 rounded-xl flex items-center justify-center">
                         <Coins size={20} />
                       </div>
                       <div>
                         <p className="text-xs font-bold text-accent2 uppercase tracking-wider">Pay with tokens</p>
                         <p className="text-sm font-medium text-textSecondary">Balance: <FETDisplay amount={fetBalance} /></p>
                       </div>
                     </div>
                     <input 
                       type="checkbox" 
                       checked={useFet} 
                       onChange={(e) => setUseFet(e.target.checked)}
                       className="w-6 h-6 rounded-lg border-border bg-surface3 text-primary focus:ring-primary"
                     />
                   </div>
                   {useFet && (
                     <div className="mt-4 pt-4 border-t border-border/50 text-success text-xs font-bold flex justify-between uppercase">
                       <span>Applied Discount</span>
                       <span>
                         -{venue?.country === 'RW' ? '' : '€'}{fetDiscount.toLocaleString()} {venue?.country === 'RW' ? 'RWF' : ''}
                       </span>
                     </div>
                   )}
                </div>

                <div className="space-y-3 mb-8 pt-4 border-t border-border">
                  <div className="flex justify-between text-textSecondary">
                    <span>Subtotal</span>
                    <span>
                      {venue?.country === 'RW' ? '' : '€'}{subtotal.toLocaleString()} {venue?.country === 'RW' ? 'RWF' : ''}
                    </span>
                  </div>
                  <div className="flex justify-between text-2xl font-black text-text">
                    <span>Total</span>
                    <span className="text-primary">
                      {venue?.country === 'RW' ? '' : '€'}{total.toLocaleString()} {venue?.country === 'RW' ? 'RWF' : ''}
                    </span>
                  </div>
                </div>

                <button 
                  disabled={orderStatus === 'submitting'}
                  onClick={handlePlaceOrder}
                  className="w-full h-16 bg-primary text-primaryText font-black text-lg rounded-2xl shadow-xl shadow-primary/20 disabled:opacity-50"
                >
                  {orderStatus === 'submitting' ? 'PLACING ORDER...' : 'PLACE ORDER'}
                </button>
                <p className="mt-4 text-center text-xs text-textSecondary font-medium">
                  Payment is handled manually at the venue.
                </p>
              </div>
            </motion.div>
          </>
        )}
      </AnimatePresence>
    </div>
  );
};
