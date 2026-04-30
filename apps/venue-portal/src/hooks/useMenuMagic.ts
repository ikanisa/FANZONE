import { useState } from 'react';
import { supabase } from '../lib/supabase';

export interface ScannedMenuItem {
  name: string;
  description: string | null;
  price: number;
  category: string | null;
}

export function useMenuMagic() {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const scanMenu = async (file: File): Promise<ScannedMenuItem[]> => {
    setLoading(true);
    setError(null);

    try {
      // 1. Convert to Base64
      const reader = new FileReader();
      const base64Promise = new Promise<string>((resolve) => {
        reader.onload = () => {
          const base64 = (reader.result as string).split(',')[1];
          resolve(base64);
        };
      });
      reader.readAsDataURL(file);
      const image_base64 = await base64Promise;

      // 2. Call Edge Function
      const { data, error: functionError } = await supabase.functions.invoke('menu_ocr_parse', {
        body: {
          image_base64,
          mime_type: file.type,
        },
      });

      if (functionError) throw functionError;
      if (!data.success) throw new Error(data.error || 'Failed to scan menu');

      return data.items as ScannedMenuItem[];
    } catch (err: any) {
      const msg = err.message || 'An unexpected error occurred during OCR.';
      setError(msg);
      return [];
    } finally {
      setLoading(false);
    }
  };

  return { scanMenu, loading, error };
}
