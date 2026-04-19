// FANZONE Admin — Global Search Hook
import { useState, useCallback, useEffect, useRef } from 'react';
import { isSupabaseConfigured, supabase } from '../lib/supabase';
import { searchEntities } from '../features/search/searchClient';
import { TYPE_ICONS, type SearchResult } from '../features/search/searchTypes';

/* ── Hook ── */
export function useGlobalSearch() {
  const [query, setQuery] = useState('');
  const [results, setResults] = useState<SearchResult[]>([]);
  const [isOpen, setIsOpen] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [selectedIndex, setSelectedIndex] = useState(0);
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const search = useCallback(async (q: string) => {
    if (q.length < 2) {
      setResults([]);
      setError(null);
      return;
    }

    setIsLoading(true);
    setError(null);
    if (!isSupabaseConfigured) {
      setResults([]);
      setSelectedIndex(0);
      setError('Search is unavailable until Supabase is configured.');
      setIsLoading(false);
      return;
    }

    try {
      const mapped = await searchEntities(supabase, q);
      setResults(mapped);
      setSelectedIndex(0);
      setError(null);
    } catch (err) {
      console.error('[GlobalSearch] failed:', err);
      setResults([]);
      setSelectedIndex(0);
      setError('Search is temporarily unavailable. Please try again.');
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
  const close = () => {
    setIsOpen(false);
    setQuery('');
    setResults([]);
    setSelectedIndex(0);
    setError(null);
  };

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
    query, setQuery, results, groupedResults, isOpen, isLoading, error,
    selectedIndex, setSelectedIndex, open, close, moveSelection,
    getSelectedResult, TYPE_ICONS,
  };
}

export type GlobalSearchController = ReturnType<typeof useGlobalSearch>;
