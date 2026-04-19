// FANZONE Admin — Partners Data Hooks
import {
  useSupabasePaginated,
  useRpcMutation,
  type AdminListQuery,
} from '../../hooks/useSupabaseQuery';
import type { Partner } from '../../types';
import type { PaginationOpts } from '../../hooks/useSupabaseQuery';

/* ── Demo Data ── */
const DEMO_PARTNERS: Partner[] = [
  { id: 'pt-1', name: 'Bar Castello', slug: 'bar-castello', category: 'bar', description: 'Historic bar in Valletta with outdoor seating overlooking the Grand Harbour.', logo_url: null, contact_email: 'info@barcastello.mt', contact_phone: '+356 2123 4567', website_url: 'https://barcastello.mt', country: 'MT', market: 'malta', status: 'approved', is_featured: true, approved_by: 'a-001', metadata: { rewards_count: 3 }, created_at: '2026-02-01T10:00:00Z', updated_at: '2026-04-10T14:00:00Z' },
  { id: 'pt-2', name: 'Café del Mar Malta', slug: 'cafe-del-mar', category: 'hospitality', description: 'Premium beach club and sunset venue in St Paul\'s Bay.', logo_url: null, contact_email: 'partners@cafedelmarmalta.com', contact_phone: '+356 2157 8900', website_url: 'https://cafedelmarmalta.com', country: 'MT', market: 'malta', status: 'approved', is_featured: true, approved_by: 'a-001', metadata: { rewards_count: 5 }, created_at: '2026-02-15T09:00:00Z', updated_at: '2026-04-12T16:00:00Z' },
  { id: 'pt-3', name: 'Fortina Spa Resort', slug: 'fortina-spa', category: 'leisure', description: 'Five-star spa and wellness resort in Sliema.', logo_url: null, contact_email: 'partnerships@fortina.com', contact_phone: '+356 2346 0000', website_url: 'https://fortinasparesort.com', country: 'MT', market: 'malta', status: 'approved', is_featured: false, approved_by: 'a-002', metadata: { rewards_count: 2 }, created_at: '2026-03-01T10:00:00Z', updated_at: '2026-04-05T11:00:00Z' },
  { id: 'pt-4', name: 'Hugo\'s Lounge', slug: 'hugos-lounge', category: 'bar', description: 'Stylish lounge bar in St Julians, popular for match-day events.', logo_url: null, contact_email: 'events@hugos.mt', contact_phone: '+356 2138 5678', website_url: 'https://hugos.mt', country: 'MT', market: 'malta', status: 'pending', is_featured: false, approved_by: null, metadata: {}, created_at: '2026-04-10T12:00:00Z', updated_at: '2026-04-10T12:00:00Z' },
  { id: 'pt-5', name: 'GasanMamo Insurance', slug: 'gasanmamo', category: 'insurance', description: 'Major Maltese insurance company exploring sports sponsorships.', logo_url: null, contact_email: 'sponsorships@gasanmamo.com', contact_phone: '+356 2146 1234', website_url: 'https://gasanmamo.com', country: 'MT', market: 'malta', status: 'pending', is_featured: false, approved_by: null, metadata: {}, created_at: '2026-04-12T08:00:00Z', updated_at: '2026-04-12T08:00:00Z' },
  { id: 'pt-6', name: 'Bay Street Complex', slug: 'bay-street', category: 'merchant', description: 'Shopping and entertainment complex in St Julians.', logo_url: null, contact_email: 'marketing@baystreet.com.mt', contact_phone: '+356 2138 9999', website_url: 'https://baystreet.com.mt', country: 'MT', market: 'malta', status: 'rejected', is_featured: false, approved_by: null, metadata: { rejection_reason: 'Category not aligned with platform focus' }, created_at: '2026-03-20T14:00:00Z', updated_at: '2026-03-22T10:00:00Z' },
];

/* ── Hooks ── */
export function usePartners(pagination: PaginationOpts, filters?: { search?: string; status?: string }) {
  return useSupabasePaginated<Partner>(['partners', filters], 'partners', {
    pagination,
    select: '*',
    filters: (query: AdminListQuery<Partner>) => {
      let q = query;
      if (filters?.status && filters.status !== 'all') {
        q = q.eq('status', filters.status);
      }
      return q;
    },
    order: { column: 'created_at', ascending: false },
    demoData: DEMO_PARTNERS.filter(p => {
      if (filters?.status && filters.status !== 'all' && p.status !== filters.status) return false;
      if (filters?.search) {
        const q = filters.search.toLowerCase();
        return p.name.toLowerCase().includes(q) || p.category.toLowerCase().includes(q) || p.id.includes(q);
      }
      return true;
    }),
  });
}

export function useApprovePartner() {
  return useRpcMutation<{ p_partner_id: string }>({
    fnName: 'admin_approve_partner',
    invalidateKeys: [['partners'], ['dashboard-kpis']],
    successMessage: 'Partner approved successfully.',
    demoFn: async () => ({ approved: true }),
  });
}

export function useRejectPartner() {
  return useRpcMutation<{ p_partner_id: string; p_reason: string }>({
    fnName: 'admin_reject_partner',
    invalidateKeys: [['partners']],
    successMessage: 'Partner rejected.',
    demoFn: async () => ({ rejected: true }),
  });
}

export function useToggleFeatured() {
  return useRpcMutation<{ p_partner_id: string; p_is_featured: boolean }>({
    fnName: 'admin_set_partner_featured',
    invalidateKeys: [['partners']],
    successMessage: 'Partner featured status updated.',
    demoFn: async () => ({ toggled: true }),
  });
}
