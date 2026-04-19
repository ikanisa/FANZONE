// FANZONE Admin — Global Search Hook
import { useState, useCallback, useEffect, useRef } from 'react';
import { isDemoMode, isSupabaseConfigured, supabase } from '../lib/supabase';
import { searchEntities } from '../features/search/searchClient';
import { TYPE_ICONS, type SearchResult } from '../features/search/searchTypes';

/* ── Demo Data ── */
const DEMO_RESULTS: SearchResult[] = [
  { id: 'u-001', type: 'user', title: 'Marco Spiteri', subtitle: 'marco@gmail.com', route: '/users?q=Marco' },
  { id: 'u-002', type: 'user', title: 'Sarah Borg', subtitle: '+356 7945 6789', route: '/users?q=Sarah' },
  { id: 'u-005', type: 'user', title: 'Daniel Grech', subtitle: '56,700 FET', route: '/users?q=Daniel' },
  { id: 'u-006', type: 'user', title: 'Isla Camilleri', subtitle: 'isla.c@gmail.com', route: '/users?q=Isla' },
  { id: 'f-001', type: 'fixture', title: 'Valletta FC vs Floriana FC', subtitle: 'MPL R28 — Apr 19', route: '/fixtures?q=Valletta' },
  { id: 'f-003', type: 'fixture', title: 'Liverpool vs Barcelona', subtitle: 'UCL QF — Apr 22', route: '/fixtures?q=Liverpool' },
  { id: 'f-004', type: 'fixture', title: 'Arsenal vs Man City', subtitle: 'EPL R35 — LIVE', route: '/fixtures?q=Arsenal' },
  { id: 'p-1482', type: 'pool', title: 'Pool #1482 — 500 FET', subtitle: '8 players — Open', route: '/challenges?q=1482' },
  { id: 'p-1478', type: 'pool', title: 'Pool #1478 — 2,000 FET', subtitle: '10 players — Settled', route: '/challenges?q=1478' },
  { id: 'pt-1', type: 'partner', title: 'Bar Castello', subtitle: 'Bar — Approved', route: '/partners?q=Castello' },
  { id: 'pt-2', type: 'partner', title: 'Café del Mar Malta', subtitle: 'Hospitality — Approved', route: '/partners?q=Cafe' },
  { id: 'pt-4', type: 'partner', title: 'Hugo\'s Lounge', subtitle: 'Bar — Pending', route: '/partners?q=Hugo' },
  { id: 'r-1', type: 'reward', title: 'Free coffee at Bar Castello', subtitle: '500 FET', route: '/rewards?q=coffee' },
  { id: 'cmp-1', type: 'campaign', title: 'Weekend Pool Bonanza', subtitle: 'In-App — Sent', route: '/notifications?q=bonanza' },
];

/* ── Hook ── */
export function useGlobalSearch() {
  const [query, setQuery] = useState('');
  const [results, setResults] = useState<SearchResult[]>([]);
  const [isOpen, setIsOpen] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [selectedIndex, setSelectedIndex] = useState(0);
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const search = useCallback(async (q: string) => {
    if (q.length < 2) {
      setResults([]);
      return;
    }

    setIsLoading(true);

    if (isDemoMode) {
      // Demo: filter local data
      const lower = q.toLowerCase();
      const filtered = DEMO_RESULTS.filter(
        r => r.title.toLowerCase().includes(lower) || r.subtitle.toLowerCase().includes(lower) || r.id.includes(lower)
      );
      setResults(filtered.slice(0, 8));
      setSelectedIndex(0);
      setIsLoading(false);
      return;
    }
    if (!isSupabaseConfigured) {
      setResults([]);
      setSelectedIndex(0);
      setIsLoading(false);
      return;
    }

    try {
      const mapped = await searchEntities(supabase, q);
      setResults(mapped);
      setSelectedIndex(0);
    } catch (err) {
      console.error('[GlobalSearch] failed:', err);
    } finally {
      setIsLoading(false);
    }
  }, []);

  // Debounced search
  useEffect(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(() => search(query), 200);
    return () => { if (debounceRef.current) clearTimeout(debounceRef.current); };
  }, [query, search]);

  // Keyboard shortcut: Cmd/Ctrl + K
  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
        e.preventDefault();
        setIsOpen(prev => !prev);
      }
      if (e.key === 'Escape') {
        setIsOpen(false);
      }
    };
    document.addEventListener('keydown', handler);
    return () => document.removeEventListener('keydown', handler);
  }, []);

  const open = () => setIsOpen(true);
  const close = () => { setIsOpen(false); setQuery(''); setResults([]); setSelectedIndex(0); };

  const moveSelection = (dir: 'up' | 'down') => {
    setSelectedIndex(i => {
      if (results.length === 0) return 0;
      if (dir === 'up') return Math.max(0, i - 1);
      return Math.min(results.length - 1, i + 1);
    });
  };

  const getSelectedResult = () => results[selectedIndex] ?? null;

  const groupedResults = results.reduce<Record<string, SearchResult[]>>((acc, r) => {
    if (!acc[r.type]) acc[r.type] = [];
    acc[r.type].push(r);
    return acc;
  }, {});

  return {
    query, setQuery, results, groupedResults, isOpen, isLoading,
    selectedIndex, setSelectedIndex, open, close, moveSelection,
    getSelectedResult, TYPE_ICONS,
  };
}

export type GlobalSearchController = ReturnType<typeof useGlobalSearch>;
