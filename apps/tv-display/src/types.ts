import type { MenuItemRow, Venue } from "@fanzone/core";
import type {
  TvGameDisplay,
  TvPoolDisplay,
  VenueScreenState,
} from "./services/tvData";

export type ScreenData = {
  venue: Venue | null;
  state: VenueScreenState | null;
  pool: TvPoolDisplay | null;
  game: TvGameDisplay | null;
  menuItems: MenuItemRow[];
  loading: boolean;
  error: string | null;
  refreshedAt: Date | null;
};
