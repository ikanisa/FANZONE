import { useCallback, useRef, useState, type ReactNode } from 'react';

import type { Toast } from './toast-context';
import { ToastContext } from './toast-context';

interface ToastProviderProps {
  children: ReactNode;
}

export function ToastProvider({ children }: ToastProviderProps) {
  const [toasts, setToasts] = useState<Toast[]>([]);
  const sequence = useRef(0);

  const addToast = useCallback((type: Toast['type'], message: string) => {
    sequence.current += 1;
    const id = `toast-${Date.now()}-${sequence.current}`;

    setToasts((currentToasts) => [...currentToasts, { id, type, message }]);

    window.setTimeout(() => {
      setToasts((currentToasts) =>
        currentToasts.filter((toast) => toast.id !== id),
      );
    }, 4000);
  }, []);

  const removeToast = useCallback((id: string) => {
    setToasts((currentToasts) =>
      currentToasts.filter((toast) => toast.id !== id),
    );
  }, []);

  return (
    <ToastContext.Provider value={{ toasts, addToast, removeToast }}>
      {children}
    </ToastContext.Provider>
  );
}
