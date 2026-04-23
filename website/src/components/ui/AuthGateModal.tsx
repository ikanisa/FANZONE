import { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { useAppStore } from '../../store/useAppStore';
import { X, MessageCircle, User } from 'lucide-react';

export function AuthGateModal() {
  const { showAuthGate, closeAuthGate, verifyPhone } = useAppStore();
  const [step, setStep] = useState<'phone' | 'otp'>('phone');
  const [phone, setPhone] = useState('');
  const [otp, setOtp] = useState(['', '', '', '', '', '']);
  const [isLoading, setIsLoading] = useState(false);

  // Reset state when modal opens
  useEffect(() => {
    if (showAuthGate) {
      setStep('phone');
      setPhone('');
      setOtp(['', '', '', '', '', '']);
      setIsLoading(false);
    }
  }, [showAuthGate]);

  const handleSendOTP = () => {
    if (phone.length < 8) return;
    setIsLoading(true);
    // Simulate API call
    setTimeout(() => {
      setIsLoading(false);
      setStep('otp');
    }, 1000);
  };

  const handleVerifyOTP = () => {
    if (otp.join('').length < 6) return;
    setIsLoading(true);
    // Simulate API call
    setTimeout(() => {
      setIsLoading(false);
      verifyPhone();
      closeAuthGate();
    }, 1000);
  };

  const handleOtpChange = (index: number, value: string) => {
    if (value.length > 1) return;
    const newOtp = [...otp];
    newOtp[index] = value;
    setOtp(newOtp);
    
    // Auto-advance
    if (value && index < 5) {
      const nextInput = document.getElementById(`otp-${index + 1}`);
      nextInput?.focus();
    }
  };

  return (
    <AnimatePresence>
      {showAuthGate && (
        <>
          {/* Backdrop */}
          <motion.div 
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={step === 'setup' ? undefined : closeAuthGate}
            className="fixed inset-0 bg-bg/80 backdrop-blur-sm z-50"
          />

          {/* Bottom Sheet */}
          <motion.div 
            initial={{ y: '100%' }}
            animate={{ y: 0 }}
            exit={{ y: '100%' }}
            transition={{ type: 'spring', damping: 25, stiffness: 200 }}
            className="fixed bottom-0 left-0 right-0 bg-surface2 border-t border-border rounded-t-3xl z-50 p-6 lg:p-8 max-w-md mx-auto"
          >
            {step !== 'setup' && (
              <button 
                onClick={closeAuthGate}
                className="absolute top-4 right-4 w-8 h-8 flex items-center justify-center rounded-full bg-surface3 text-muted hover:text-text transition-colors"
              >
                <X size={18} />
              </button>
            )}

            {step === 'phone' && (
              <div className="flex flex-col gap-6">
                <div className="flex items-center gap-3 text-[#25D366]">
                  <MessageCircle size={24} />
                  <h3 className="font-display text-xl tracking-widest">VERIFY VIA WHATSAPP</h3>
                </div>
                
                <p className="text-sm text-muted">
                  Verify your number to secure wallet activity and unlock the full prediction flow. It's 100% free.
                </p>

                <div className="flex gap-3">
                  <div className="bg-surface3 border border-border rounded-xl px-4 flex items-center justify-center text-text font-bold w-24">
                    +250
                  </div>
                  <input 
                    type="tel" 
                    placeholder="78X XXX XXX" 
                    value={phone}
                    onChange={(e) => setPhone(e.target.value)}
                    className="flex-1 bg-surface3 border border-border rounded-xl p-4 text-text font-mono focus:outline-none focus:border-[#25D366] transition-all"
                    autoFocus
                  />
                </div>

                <button 
                  onClick={handleSendOTP}
                  disabled={phone.length < 8 || isLoading}
                  className="w-full bg-[#25D366] hover:bg-[#25D366]/90 disabled:opacity-50 disabled:cursor-not-allowed text-[#1a1400] font-bold py-4 rounded-xl transition-all flex justify-center items-center gap-2"
                >
                  {isLoading ? 'SENDING...' : 'SEND CODE VIA WHATSAPP'}
                </button>

                <div className="text-center">
                  <button onClick={closeAuthGate} className="text-xs text-muted hover:text-text font-bold transition-colors">
                    Continue as Guest
                  </button>
                </div>
              </div>
            )}

            {step === 'otp' && (
              <div className="flex flex-col gap-6">
                <div className="flex items-center gap-3 text-[#25D366]">
                  <MessageCircle size={24} />
                  <h3 className="font-display text-xl tracking-widest">ENTER OTP</h3>
                </div>
                
                <p className="text-sm text-muted">
                  Enter the 6-digit code sent to your WhatsApp.
                </p>

                <div className="flex gap-2 justify-between">
                  {otp.map((digit, i) => (
                    <input 
                      key={i}
                      id={`otp-${i}`}
                      type="text" 
                      maxLength={1}
                      value={digit}
                      onChange={(e) => handleOtpChange(i, e.target.value)}
                      className="w-12 h-14 bg-surface3 border border-border rounded-xl text-center text-text font-mono text-xl focus:outline-none focus:border-[#25D366] transition-all"
                    />
                  ))}
                </div>

                <button 
                  onClick={handleVerifyOTP}
                  disabled={otp.join('').length < 6 || isLoading}
                  className="w-full bg-[#25D366] hover:bg-[#25D366]/90 disabled:opacity-50 disabled:cursor-not-allowed text-[#1a1400] font-bold py-4 rounded-xl transition-all flex justify-center items-center gap-2"
                >
                  {isLoading ? 'VERIFYING...' : 'VERIFY CODE'}
                </button>

                <div className="text-center">
                  <p className="text-[10px] text-muted">Your number is never shown to others.</p>
                </div>
              </div>
            )}
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}
