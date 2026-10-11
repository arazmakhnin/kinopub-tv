import { create } from 'zustand';
import type { Item } from '../types';

interface SearchState {
  query: string;
  results: ReadonlyArray<Item>;
  hasSearched: boolean;
  focusedCardIndex: number;
  setQuery: (query: string) => void;
  setResults: (results: ReadonlyArray<Item>) => void;
  setHasSearched: (hasSearched: boolean) => void;
  setFocusedCardIndex: (focusedCardIndex: number) => void;
}

export const useSearchStore = create<SearchState>()((set) => ({
  query: '',
  results: [],
  hasSearched: false,
  focusedCardIndex: 0,

  setQuery(query: string): void {
    set({ query });
  },

  setResults(results: ReadonlyArray<Item>): void {
    set({ results });
  },

  setHasSearched(hasSearched: boolean): void {
    set({ hasSearched });
  },

  setFocusedCardIndex(focusedCardIndex: number): void {
    set({ focusedCardIndex });
  },
}));
