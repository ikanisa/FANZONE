import { createClient } from '@supabase/supabase-js';
import { Database } from '@fanzone/core'; // Assuming we'll generate types

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || '';
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY || '';

export const supabase = createClient(supabaseUrl, supabaseAnonKey);
