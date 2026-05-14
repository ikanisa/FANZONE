import { type FormEvent, useState } from "react";
import { useNavigate } from "react-router-dom";
import { MonitorPlay } from "lucide-react";

export function PairingPage() {
  const navigate = useNavigate();
  const [venueKey, setVenueKey] = useState("");

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const nextKey = venueKey.trim();
    if (nextKey) navigate(`/venue/${encodeURIComponent(nextKey)}`);
  }

  return (
    <main className="pairing-page">
      <section className="pairing-copy">
        <div className="brand-lockup">
          <img src="/brand/logo-mark-128.png" alt="" />
          <span>FANZONE TV</span>
        </div>
        <h1>Venue live screen</h1>
        <p>
          Pair this display with one venue to show QR joins, prediction pools,
          game rounds, leaderboards, winners, menu highlights, and FET
          eligibility reminders.
        </p>
      </section>
      <form className="pairing-card" onSubmit={submit}>
        <label htmlFor="venue-key">Venue ID or slug</label>
        <input
          id="venue-key"
          value={venueKey}
          onChange={(event) => setVenueKey(event.target.value)}
          placeholder="sports-bar-slug"
          autoComplete="off"
        />
        <button type="submit">
          <MonitorPlay size={22} />
          Pair Display
        </button>
      </form>
    </main>
  );
}
