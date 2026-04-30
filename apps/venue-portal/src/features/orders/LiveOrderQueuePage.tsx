import React from 'react';
import { 
  ClipboardList, 
  Clock, 
  CheckCircle2, 
  AlertCircle,
  BellRing,
  Check,
  Loader2
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { useOrders } from '../../hooks/useOrders';
import { Order, OrderStatus } from '@fanzone/core';

export const LiveOrderQueuePage: React.FC = () => {
  // In a real app, venueId comes from auth context
  const venueId = 'v1'; 
  const { orders, loading, error, updateOrderStatus } = useOrders(venueId);

  if (loading) {
    return (
      <div className="h-full flex items-center justify-center">
        <Loader2 className="animate-spin text-primary" size={48} />
      </div>
    );
  }

  if (error) {
    return (
      <div className="h-full flex flex-col items-center justify-center text-danger">
        <AlertCircle size={48} />
        <p className="mt-4 font-bold">Failed to load live queue: {error}</p>
      </div>
    );
  }

  const Column = ({ title, status, icon, color }: any) => (
    <div className="flex-1 min-w-[350px] flex flex-col h-full bg-surface3/30 rounded-[32px] border border-border overflow-hidden">
      <div className="p-6 border-b border-border bg-white flex justify-between items-center">
        <div className="flex items-center gap-3">
          <div className={`w-8 h-8 rounded-lg flex items-center justify-center ${color} text-white`}>
            {icon}
          </div>
          <h3 className="font-black text-lg uppercase tracking-tight">{title}</h3>
        </div>
        <span className="bg-surface2 px-3 py-1 rounded-full text-xs font-black">
          {orders.filter(o => o.status === status).length}
        </span>
      </div>
      <div className="flex-1 overflow-y-auto p-4 space-y-4 no-scrollbar">
         <AnimatePresence mode="popLayout">
            {orders.filter(o => o.status === status).map((order) => (
              <motion.div 
                layout
                initial={{ opacity: 0, scale: 0.9 }}
                animate={{ opacity: 1, scale: 1 }}
                exit={{ opacity: 0, x: 20 }}
                key={order.id} 
                className="bg-white p-6 rounded-2xl border border-border shadow-sm hover:shadow-md transition-shadow group"
              >
                 <div className="flex justify-between items-start mb-4">
                    <div className="flex items-center gap-3">
                       <div className="w-10 h-10 bg-primary text-primaryText rounded-xl flex items-center justify-center font-black text-sm">
                          {order.tableId}
                       </div>
                       <div>
                          <p className="text-[10px] font-black text-textSecondary uppercase tracking-widest">Order</p>
                          <h4 className="font-black text-lg leading-none">#{order.orderCode}</h4>
                       </div>
                    </div>
                    <div className="text-right">
                       <p className="text-[10px] font-bold text-textSecondary uppercase">
                         {new Date(order.createdAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                       </p>
                       <p className="font-black text-primary">€{order.totalAmount.toFixed(2)}</p>
                    </div>
                 </div>

                 <div className="space-y-2 mb-6">
                    {order.items?.map((item, i) => (
                      <p key={i} className="text-sm font-medium text-text flex gap-2">
                        <span className="text-primary opacity-30">•</span> 
                        {item.quantity}x {item.itemNameSnapshot}
                      </p>
                    ))}
                 </div>

                 <div className="flex gap-2">
                    {order.status === 'placed' && (
                      <button 
                        onClick={() => updateOrderStatus(order.id, 'received')}
                        className="flex-1 h-12 bg-primary text-primaryText font-black rounded-xl text-xs hover:opacity-90 active:scale-95 transition-all uppercase tracking-widest"
                      >
                         Accept Order
                      </button>
                    )}
                    {order.status === 'received' && (
                      <button 
                        onClick={() => updateOrderStatus(order.id, 'served')}
                        className="flex-1 h-12 bg-success text-white font-black rounded-xl text-xs hover:opacity-90 active:scale-95 transition-all uppercase tracking-widest"
                      >
                         Mark Served
                      </button>
                    )}
                 </div>
              </motion.div>
            ))}
         </AnimatePresence>
      </div>
    </div>
  );

  return (
    <div className="h-full flex flex-col gap-8 max-w-[1400px] mx-auto">
      <div className="flex justify-between items-end shrink-0">
        <div>
          <h1 className="text-4xl font-black tracking-tighter">Live Order Queue</h1>
          <p className="text-textSecondary font-medium mt-1">Real-time KDS for your venue kitchen and staff.</p>
        </div>
        <div className="flex items-center gap-4">
           <div className="bg-white border border-border p-4 rounded-[24px] flex items-center gap-4">
              <div className="flex items-center gap-2">
                 <div className="w-2 h-2 bg-success rounded-full animate-pulse" />
                 <span className="text-xs font-black uppercase tracking-widest">Kitchen Live</span>
              </div>
           </div>
        </div>
      </div>

      <div className="flex-1 flex gap-6 overflow-x-auto no-scrollbar pb-4 min-h-0">
        <Column 
          title="New Arrivals" 
          status="placed" 
          icon={<AlertCircle size={18} />} 
          color="bg-primary"
        />
        <Column 
          title="Preparing" 
          status="received" 
          icon={<Clock size={18} />} 
          color="bg-warning"
        />

        {/* Table Assistance Sidebar */}
        <div className="w-80 flex flex-col h-full bg-white rounded-[32px] border border-border overflow-hidden">
           <div className="p-6 border-b border-border flex items-center gap-3">
              <div className="w-8 h-8 rounded-lg bg-accent2 flex items-center justify-center text-white">
                 <BellRing size={18} />
              </div>
              <h3 className="font-black text-lg uppercase tracking-tight">Assistance</h3>
           </div>
           <div className="flex-1 overflow-y-auto p-4 space-y-3">
              <div className="bg-surface2 border border-border p-4 rounded-2xl text-center text-textSecondary text-sm font-medium">
                 No active assistance requests.
              </div>
           </div>
        </div>
      </div>
    </div>
  );
};
