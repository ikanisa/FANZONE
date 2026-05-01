import React, { useCallback, useEffect, useMemo, useState } from 'react';
import {
  Eye,
  EyeOff,
  GripVertical,
  ImageOff,
  Pencil,
  Plus,
  Search,
  Trash2,
  Wand2,
} from 'lucide-react';
import { Reorder } from 'motion/react';
import { MenuMagicModal } from '../../components/MenuMagicModal';
import { ScannedMenuItem } from '../../hooks/useMenuMagic';
import { supabase } from '../../lib/supabase';
import { useVenue } from '../../hooks/useVenueContext';
import type { MenuCategoryRow, MenuItemRow } from '@fanzone/core';

type CategoryView = {
  id: string;
  name: string;
  displayOrder: number;
  isVisible: boolean;
  itemCount: number;
};

type MenuItemView = {
  id: string;
  categoryId: string;
  name: string;
  description: string | null;
  price: number;
  currencyCode: string;
  imageUrl: string | null;
  isAvailable: boolean;
  displayOrder: number;
  fetEarnPercentOverride: number | null;
};

function truncateValue(value: string, fallback: string, maxLength: number) {
  const trimmed = value.trim();
  return (trimmed || fallback).slice(0, maxLength);
}

function parsePrice(value: string | null) {
  if (value === null) return null;
  const parsed = Number(value.replace(/[^0-9.]/g, ''));
  return Number.isFinite(parsed) && parsed >= 0 ? parsed : null;
}

function formatPrice(currencyCode: string, price: number) {
  return currencyCode === 'EUR' ? `€${price.toFixed(2)}` : `${currencyCode} ${price.toFixed(0)}`;
}

export const MenuArchitectPage: React.FC = () => {
  const { venue, member, loading: venueLoading, error: venueError } = useVenue();
  const [isMagicModalOpen, setIsMagicModalOpen] = useState(false);
  const [categories, setCategories] = useState<CategoryView[]>([]);
  const [items, setItems] = useState<MenuItemView[]>([]);
  const [selectedCategoryId, setSelectedCategoryId] = useState<string | null>(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const [statusMessage, setStatusMessage] = useState<string | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const currencyCode = venue?.country === 'RW' ? 'RWF' : 'EUR';
  const canDeleteItems = member?.role === 'owner' || member?.role === 'manager';

  const mapCategory = useCallback((row: MenuCategoryRow, itemCount = 0): CategoryView => ({
    id: row.id,
    name: row.name,
    displayOrder: row.display_order,
    isVisible: row.is_visible,
    itemCount,
  }), []);

  const mapItem = useCallback((row: MenuItemRow): MenuItemView => ({
    id: row.id,
    categoryId: row.category_id,
    name: row.name,
    description: row.description,
    price: Number(row.price),
    currencyCode: row.currency_code,
    imageUrl: row.image_url,
    isAvailable: row.is_available,
    displayOrder: row.display_order,
    fetEarnPercentOverride: row.fet_earn_percent_override ?? null,
  }), []);

  const loadMenu = useCallback(async () => {
    if (!venue) return;

    setIsLoading(true);
    setErrorMessage(null);
    try {
      const [categoryResult, itemResult] = await Promise.all([
        supabase
          .from('menu_categories')
          .select('*')
          .eq('venue_id', venue.id)
          .order('display_order', { ascending: true }),
        supabase
          .from('menu_items')
          .select('*')
          .eq('venue_id', venue.id)
          .order('display_order', { ascending: true }),
      ]);

      if (categoryResult.error) throw categoryResult.error;
      if (itemResult.error) throw itemResult.error;

      const nextItems = (itemResult.data ?? []).map((row) => mapItem(row as MenuItemRow));
      const counts = new Map<string, number>();
      nextItems.forEach((item) => {
        counts.set(item.categoryId, (counts.get(item.categoryId) ?? 0) + 1);
      });
      const nextCategories = (categoryResult.data ?? []).map((row) =>
        mapCategory(row as MenuCategoryRow, counts.get(row.id) ?? 0)
      );

      setItems(nextItems);
      setCategories(nextCategories);
      setSelectedCategoryId((current) =>
        current && nextCategories.some((category) => category.id === current)
          ? current
          : nextCategories[0]?.id ?? null
      );
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : 'Failed to load menu.');
    } finally {
      setIsLoading(false);
    }
  }, [mapCategory, mapItem, venue]);

  useEffect(() => {
    const loadTimer = window.setTimeout(() => {
      void loadMenu();
    }, 0);

    return () => window.clearTimeout(loadTimer);
  }, [loadMenu]);

  const selectedCategory = useMemo(
    () => categories.find((category) => category.id === selectedCategoryId) ?? null,
    [categories, selectedCategoryId],
  );

  const filteredItems = useMemo(() => {
    const normalizedSearch = searchTerm.trim().toLowerCase();
    return items
      .filter((item) => !selectedCategoryId || item.categoryId === selectedCategoryId)
      .filter((item) => {
        if (!normalizedSearch) return true;
        return (
          item.name.toLowerCase().includes(normalizedSearch) ||
          item.description?.toLowerCase().includes(normalizedSearch)
        );
      })
      .sort((a, b) => a.displayOrder - b.displayOrder);
  }, [items, searchTerm, selectedCategoryId]);

  const requireVenue = () => {
    if (!venue) {
      setErrorMessage('Venue context is required before editing a menu.');
      return null;
    }
    return venue;
  };

  const handleAddCategory = async () => {
    const activeVenue = requireVenue();
    if (!activeVenue) return;

    const name = window.prompt('Category name');
    if (!name) return;

    setIsSaving(true);
    setErrorMessage(null);
    try {
      const { data, error } = await supabase
        .from('menu_categories')
        .insert({
          venue_id: activeVenue.id,
          name: truncateValue(name, 'New Category', 80),
          display_order: categories.length,
          is_visible: true,
        })
        .select()
        .single();

      if (error) throw error;
      const category = mapCategory(data as MenuCategoryRow, 0);
      setCategories((current) => [...current, category]);
      setSelectedCategoryId(category.id);
      setStatusMessage('Category saved.');
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : 'Failed to add category.');
    } finally {
      setIsSaving(false);
    }
  };

  const handleReorderCategories = async (nextCategories: CategoryView[]) => {
    const reordered = nextCategories.map((category, index) => ({
      ...category,
      displayOrder: index,
    }));
    setCategories(reordered);

    setIsSaving(true);
    setErrorMessage(null);
    try {
      const updates = await Promise.all(
        reordered.map((category) =>
          supabase
            .from('menu_categories')
            .update({ display_order: category.displayOrder })
            .eq('id', category.id),
        ),
      );
      const failed = updates.find((result) => result.error);
      if (failed?.error) throw failed.error;
      setStatusMessage('Category order saved.');
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : 'Failed to save category order.');
      void loadMenu();
    } finally {
      setIsSaving(false);
    }
  };

  const handleToggleCategoryVisibility = async (category: CategoryView) => {
    setIsSaving(true);
    setErrorMessage(null);
    try {
      const { error } = await supabase
        .from('menu_categories')
        .update({ is_visible: !category.isVisible })
        .eq('id', category.id);

      if (error) throw error;
      setCategories((current) =>
        current.map((item) =>
          item.id === category.id ? { ...item, isVisible: !category.isVisible } : item,
        ),
      );
      setStatusMessage(!category.isVisible ? 'Category visible.' : 'Category hidden.');
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : 'Failed to update category.');
    } finally {
      setIsSaving(false);
    }
  };

  const handleAddItem = async () => {
    const activeVenue = requireVenue();
    if (!activeVenue || !selectedCategoryId) return;

    const name = window.prompt('Item name');
    if (!name) return;
    const price = parsePrice(window.prompt(`Price in ${currencyCode}`));
    if (price === null) {
      setErrorMessage('Enter a valid item price.');
      return;
    }
    const description = window.prompt('Description')?.trim() || null;
    const imageUrl = window.prompt('Image URL')?.trim() || null;
    const overrideInput = window.prompt('FET reward override percent. Leave blank for venue default.');
    const fetEarnPercentOverride =
      overrideInput && overrideInput.trim() !== ''
        ? Math.min(100, Math.max(0, Number(overrideInput)))
        : null;

    setIsSaving(true);
    setErrorMessage(null);
    try {
      const { data, error } = await supabase
        .from('menu_items')
        .insert({
          venue_id: activeVenue.id,
          category_id: selectedCategoryId,
          name: truncateValue(name, 'Menu Item', 120),
          description,
          price,
          currency_code: currencyCode,
          image_url: imageUrl,
          fet_earn_percent_override: Number.isFinite(fetEarnPercentOverride)
            ? fetEarnPercentOverride
            : null,
          is_available: true,
          display_order: items.filter((item) => item.categoryId === selectedCategoryId).length,
        })
        .select()
        .single();

      if (error) throw error;
      setItems((current) => [...current, mapItem(data as MenuItemRow)]);
      setCategories((current) =>
        current.map((category) =>
          category.id === selectedCategoryId
            ? { ...category, itemCount: category.itemCount + 1 }
            : category,
        ),
      );
      setStatusMessage('Item saved.');
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : 'Failed to add item.');
    } finally {
      setIsSaving(false);
    }
  };

  const handleEditItem = async (item: MenuItemView) => {
    const name = window.prompt('Item name', item.name);
    if (!name) return;
    const price = parsePrice(window.prompt(`Price in ${item.currencyCode}`, String(item.price)));
    if (price === null) {
      setErrorMessage('Enter a valid item price.');
      return;
    }
    const description = window.prompt('Description', item.description ?? '')?.trim() || null;
    const imageUrl = window.prompt('Image URL', item.imageUrl ?? '')?.trim() || null;
    const overrideInput = window.prompt(
      'FET reward override percent. Leave blank for venue default.',
      item.fetEarnPercentOverride == null ? '' : String(item.fetEarnPercentOverride),
    );
    const fetEarnPercentOverride =
      overrideInput && overrideInput.trim() !== ''
        ? Math.min(100, Math.max(0, Number(overrideInput)))
        : null;

    setIsSaving(true);
    setErrorMessage(null);
    try {
      const { error } = await supabase
        .from('menu_items')
        .update({
          name: truncateValue(name, 'Menu Item', 120),
          price,
          description,
          image_url: imageUrl,
          fet_earn_percent_override: Number.isFinite(fetEarnPercentOverride)
            ? fetEarnPercentOverride
            : null,
        })
        .eq('id', item.id);

      if (error) throw error;
      setItems((current) =>
        current.map((currentItem) =>
          currentItem.id === item.id
            ? {
                ...currentItem,
                name: truncateValue(name, 'Menu Item', 120),
                price,
                description,
                imageUrl,
                fetEarnPercentOverride: Number.isFinite(fetEarnPercentOverride)
                  ? fetEarnPercentOverride
                  : null,
              }
            : currentItem,
        ),
      );
      setStatusMessage('Item updated.');
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : 'Failed to update item.');
    } finally {
      setIsSaving(false);
    }
  };

  const handleToggleItemAvailability = async (item: MenuItemView) => {
    setIsSaving(true);
    setErrorMessage(null);
    try {
      const { error } = await supabase
        .from('menu_items')
        .update({ is_available: !item.isAvailable })
        .eq('id', item.id);

      if (error) throw error;
      setItems((current) =>
        current.map((currentItem) =>
          currentItem.id === item.id
            ? { ...currentItem, isAvailable: !item.isAvailable }
            : currentItem,
        ),
      );
      setStatusMessage(!item.isAvailable ? 'Item is available.' : 'Item is unavailable.');
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : 'Failed to update item availability.');
    } finally {
      setIsSaving(false);
    }
  };

  const handleDeleteItem = async (item: MenuItemView) => {
    if (!window.confirm(`Delete ${item.name}?`)) return;

    setIsSaving(true);
    setErrorMessage(null);
    try {
      const { error } = await supabase.from('menu_items').delete().eq('id', item.id);
      if (error) throw error;

      setItems((current) => current.filter((currentItem) => currentItem.id !== item.id));
      setCategories((current) =>
        current.map((category) =>
          category.id === item.categoryId
            ? { ...category, itemCount: Math.max(0, category.itemCount - 1) }
            : category,
        ),
      );
      setStatusMessage('Item deleted.');
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : 'Failed to delete item.');
    } finally {
      setIsSaving(false);
    }
  };

  const handleMagicImport = async (scannedItems: ScannedMenuItem[]) => {
    const activeVenue = requireVenue();
    if (!activeVenue || scannedItems.length === 0) return;

    setIsSaving(true);
    setErrorMessage(null);
    try {
      const categoryByName = new Map(
        categories.map((category) => [category.name.trim().toLowerCase(), category]),
      );
      const categoriesToUse = [...categories];
      const itemRows: Record<string, unknown>[] = [];

      for (const scannedItem of scannedItems) {
        const categoryName = truncateValue(scannedItem.category ?? '', 'Imported', 80);
        const categoryKey = categoryName.toLowerCase();
        let category = categoryByName.get(categoryKey);

        if (!category) {
          const { data, error } = await supabase
            .from('menu_categories')
            .insert({
              venue_id: activeVenue.id,
              name: categoryName,
              display_order: categoriesToUse.length,
              is_visible: true,
            })
            .select()
            .single();

          if (error) throw error;
          category = mapCategory(data as MenuCategoryRow, 0);
          categoryByName.set(categoryKey, category);
          categoriesToUse.push(category);
        }

        itemRows.push({
          venue_id: activeVenue.id,
          category_id: category.id,
          name: truncateValue(scannedItem.name, 'Imported Item', 120),
          description: scannedItem.description?.trim() || null,
          price: Number.isFinite(scannedItem.price) ? Math.max(0, scannedItem.price) : 0,
          currency_code: currencyCode,
          is_available: true,
          display_order: items.filter((item) => item.categoryId === category?.id).length +
            itemRows.filter((row) => row.category_id === category?.id).length,
          metadata: {
            import_source: 'menu_magic',
            confidence: scannedItem.confidence ?? null,
          },
        });
      }

      const { error } = await supabase.from('menu_items').insert(itemRows);
      if (error) throw error;

      setStatusMessage(`Imported ${itemRows.length} menu items.`);
      await loadMenu();
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : 'Failed to import menu items.');
    } finally {
      setIsSaving(false);
    }
  };

  if (venueLoading || isLoading) {
    return (
      <div className="max-w-7xl mx-auto">
        <div className="bg-white p-8 rounded-[32px] border border-border font-bold text-textSecondary">
          Loading menu...
        </div>
      </div>
    );
  }

  if (venueError || !venue) {
    return (
      <div className="max-w-7xl mx-auto">
        <div className="bg-danger/10 p-6 rounded-3xl border border-danger/20 text-danger font-bold">
          {venueError ?? 'Venue context is unavailable.'}
        </div>
      </div>
    );
  }

  return (
    <div className="max-w-7xl mx-auto space-y-8">
      <div className="flex flex-col gap-4 sm:flex-row sm:justify-between sm:items-start">
        <div>
          <h1 className="text-4xl font-black tracking-tighter">Menu</h1>
          <p className="text-textSecondary font-medium mt-1">
            Manage the live digital menu for {venue.name}.
          </p>
        </div>
        <div className="flex flex-wrap gap-3">
          <button
            onClick={() => setIsMagicModalOpen(true)}
            disabled={isSaving}
            className="flex items-center gap-2 px-6 py-3 bg-accent/10 text-success rounded-xl font-bold hover:bg-accent/20 disabled:opacity-50 transition-all"
          >
            <Wand2 size={18} />
            MAGIC IMPORT
          </button>
          <button
            onClick={handleAddCategory}
            disabled={isSaving}
            className="flex items-center gap-2 px-6 py-3 bg-primary text-primaryText rounded-xl font-bold hover:opacity-90 active:scale-95 disabled:opacity-50 transition-all"
          >
            <Plus size={18} />
            ADD CATEGORY
          </button>
        </div>
      </div>

      {(statusMessage || errorMessage) && (
        <div
          className={`p-4 rounded-2xl border text-sm font-bold ${
            errorMessage
              ? 'bg-danger/10 border-danger/20 text-danger'
              : 'bg-success/10 border-success/20 text-success'
          }`}
        >
          {errorMessage ?? statusMessage}
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-8">
        <div className="lg:col-span-4 space-y-4">
          <div className="bg-white p-6 rounded-[32px] border border-border">
            <h3 className="font-black text-lg mb-4 px-2">Categories</h3>
            {categories.length === 0 ? (
              <div className="p-5 bg-surface2 rounded-2xl text-sm font-bold text-textSecondary">
                Add a category before adding menu items.
              </div>
            ) : (
              <Reorder.Group
                axis="y"
                values={categories}
                onReorder={handleReorderCategories}
                className="space-y-2"
              >
                {categories.map((cat) => (
                  <Reorder.Item
                    key={cat.id}
                    value={cat}
                    onClick={() => setSelectedCategoryId(cat.id)}
                    className={`group bg-surface2 hover:bg-surface3 border p-4 rounded-2xl flex items-center gap-3 cursor-pointer transition-all ${
                      selectedCategoryId === cat.id ? 'border-primary/40' : 'border-transparent'
                    }`}
                  >
                    <GripVertical
                      size={16}
                      className="text-textSecondary opacity-0 group-hover:opacity-100 transition-opacity"
                    />
                    <div className="flex-1 min-w-0">
                      <p className="font-bold text-sm truncate">{cat.name}</p>
                      <p className="text-[10px] font-bold text-textSecondary uppercase">
                        {cat.itemCount} Items
                      </p>
                    </div>
                    <button
                      type="button"
                      onClick={(event) => {
                        event.stopPropagation();
                        void handleToggleCategoryVisibility(cat);
                      }}
                      className="p-2 hover:bg-white rounded-lg transition-all text-textSecondary hover:text-text"
                      title={cat.isVisible ? 'Hide category' : 'Show category'}
                    >
                      {cat.isVisible ? <Eye size={14} /> : <EyeOff size={14} className="text-danger" />}
                    </button>
                  </Reorder.Item>
                ))}
              </Reorder.Group>
            )}
          </div>
        </div>

        <div className="lg:col-span-8 space-y-6">
          <div className="bg-white p-4 rounded-2xl border border-border flex items-center gap-4">
            <div className="flex-1 relative">
              <Search
                size={18}
                className="absolute left-4 top-1/2 -translate-y-1/2 text-textSecondary"
              />
              <input
                type="text"
                value={searchTerm}
                onChange={(event) => setSearchTerm(event.target.value)}
                placeholder={`Search items${selectedCategory ? ` in ${selectedCategory.name}` : ''}...`}
                className="w-full pl-12 pr-4 py-3 bg-surface2 border-transparent rounded-xl focus:bg-white focus:border-border transition-all text-sm outline-none"
              />
            </div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {filteredItems.map((item) => (
              <div
                key={item.id}
                className="bg-white p-4 rounded-3xl border border-border group hover:border-primary/20 hover:shadow-xl hover:shadow-primary/5 transition-all"
              >
                <div className="flex gap-4">
                  <div className="w-24 h-24 bg-surface2 rounded-2xl overflow-hidden shrink-0 flex items-center justify-center">
                    {item.imageUrl ? (
                      <img
                        src={item.imageUrl}
                        className="w-full h-full object-cover group-hover:scale-110 transition-transform duration-500"
                        alt={item.name}
                      />
                    ) : (
                      <ImageOff size={24} className="text-textSecondary" />
                    )}
                  </div>
                  <div className="flex-1 py-1 min-w-0">
                    <div className="flex justify-between items-start gap-2">
                      <h4 className="font-black text-lg truncate">{item.name}</h4>
                      <div className="flex gap-1 opacity-100 sm:opacity-0 sm:group-hover:opacity-100 transition-opacity">
                        <button
                          onClick={() => void handleEditItem(item)}
                          className="p-2 hover:bg-surface2 rounded-lg text-textSecondary hover:text-text"
                          title="Edit item"
                        >
                          <Pencil size={14} />
                        </button>
                        {canDeleteItems && (
                          <button
                            onClick={() => void handleDeleteItem(item)}
                            className="p-2 hover:bg-danger/10 rounded-lg text-textSecondary hover:text-danger"
                            title="Delete item"
                          >
                            <Trash2 size={14} />
                          </button>
                        )}
                      </div>
                    </div>
                    <p className="text-xs text-textSecondary line-clamp-2 mt-1 font-medium">
                      {item.description || 'No description'}
                    </p>
                    <div className="mt-3 flex items-center justify-between">
                      <span className="font-black text-primary">
                        {formatPrice(item.currencyCode, item.price)}
                      </span>
                      <button
                        type="button"
                        onClick={() => void handleToggleItemAvailability(item)}
                        disabled={isSaving}
                        className={`flex items-center gap-1 text-[10px] font-black uppercase ${
                          item.isAvailable ? 'text-success' : 'text-danger'
                        }`}
                        title={item.isAvailable ? 'Mark unavailable' : 'Mark available'}
                      >
                        <div
                          className={`w-1.5 h-1.5 rounded-full ${
                            item.isAvailable ? 'bg-success' : 'bg-danger'
                          }`}
                        />
                        {item.isAvailable ? 'Available' : 'Unavailable'}
                      </button>
                    </div>
                    {item.fetEarnPercentOverride != null && (
                      <div className="mt-2 inline-flex rounded-full bg-primary/10 text-primary px-3 py-1 text-[10px] font-black uppercase tracking-widest">
                        {item.fetEarnPercentOverride}% FET override
                      </div>
                    )}
                  </div>
                </div>
              </div>
            ))}

            <button
              onClick={handleAddItem}
              disabled={isSaving || !selectedCategoryId}
              className="border-2 border-dashed border-border rounded-3xl p-8 flex flex-col items-center justify-center gap-3 text-textSecondary hover:border-primary hover:text-primary disabled:opacity-50 disabled:hover:border-border disabled:hover:text-textSecondary transition-all group min-h-[128px]"
            >
              <div className="w-12 h-12 rounded-full bg-surface2 flex items-center justify-center group-hover:bg-primary/5 transition-colors">
                <Plus size={24} />
              </div>
              <span className="font-bold text-sm uppercase tracking-widest">Add New Item</span>
            </button>
          </div>
        </div>
      </div>

      <MenuMagicModal
        isOpen={isMagicModalOpen}
        onClose={() => setIsMagicModalOpen(false)}
        onComplete={handleMagicImport}
      />
    </div>
  );
};
