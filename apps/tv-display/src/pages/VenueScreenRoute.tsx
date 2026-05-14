import { Navigate, useParams } from "react-router-dom";
import { TvShell } from "../components/TvShell";
import { useVenueScreen } from "../hooks/useVenueScreen";

export function VenueScreenRoute() {
  const { venueKey } = useParams();
  const { data, reload } = useVenueScreen(venueKey);

  if (!venueKey) {
    return <Navigate to="/" replace />;
  }

  return <TvShell data={data} onReload={reload} />;
}
