import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import { ConfigurationError } from "./components/ConfigurationError";
import { isSupabaseConfigured } from "./lib/supabase";
import { PairingPage } from "./pages/PairingPage";
import { VenueScreenRoute } from "./pages/VenueScreenRoute";

function App() {
  if (!isSupabaseConfigured) {
    return <ConfigurationError />;
  }

  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<PairingPage />} />
        <Route path="/venue/:venueKey" element={<VenueScreenRoute />} />
        <Route path="/screen/:venueKey" element={<VenueScreenRoute />} />
        <Route path="/v/:venueKey" element={<VenueScreenRoute />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  );
}

export default App;
