import React, { useCallback, useEffect, useState } from "react";
import {
  Download,
  Loader2,
  Maximize2,
  QrCode,
  RefreshCcw,
  Share2,
  ShieldCheck,
} from "lucide-react";
import QRCode from "qrcode";
import { safeHref } from "@fanzone/core";
import { EmptyState } from "../../components/console/EmptyState";
import { StatusChip } from "../../components/console/StatusChip";
import { useVenue } from "../../hooks/useVenueContext";
import {
  fetchVenueTables,
  generateVenueTableQr,
  setVenueTableActive,
  type VenueTable,
} from "../../services/venueOperations";

export const QRFactoryPage: React.FC = () => {
  const { venue, member } = useVenue();
  const venueId = venue?.id;
  const [startRange, setStartRange] = useState("1");
  const [endRange, setEndRange] = useState("10");
  const [tables, setTables] = useState<VenueTable[]>([]);
  const [loading, setLoading] = useState(false);
  const [working, setWorking] = useState(false);
  const [statusMessage, setStatusMessage] = useState<string | null>(null);
  const [qrImages, setQrImages] = useState<Record<string, string>>({});

  const canManageTables =
    member?.role === "owner" || member?.role === "manager";

  const loadTables = useCallback(async () => {
    if (!venueId) return;
    setLoading(true);
    setStatusMessage(null);
    try {
      setTables(await fetchVenueTables(venueId));
    } catch (err) {
      setStatusMessage(
        err instanceof Error ? err.message : "Failed to load venue tables.",
      );
    } finally {
      setLoading(false);
    }
  }, [venueId]);

  useEffect(() => {
    const timer = window.setTimeout(() => {
      void loadTables();
    }, 0);

    return () => window.clearTimeout(timer);
  }, [loadTables]);

  useEffect(() => {
    let isMounted = true;
    const timer = window.setTimeout(async () => {
      const entries = await Promise.all(
        tables.map(async (table) => {
          const qrUrl = safeHref(table.qrUrl);
          if (!qrUrl) return null;
          return [
            table.id,
            await QRCode.toDataURL(qrUrl, {
              width: 420,
              margin: 2,
              errorCorrectionLevel: "M",
              color: {
                dark: "#111111",
                light: "#FFFFFF",
              },
            }),
          ] as const;
        }),
      );

      if (isMounted) {
        setQrImages(
          Object.fromEntries(entries.filter((entry) => entry !== null)),
        );
      }
    }, 0);

    return () => {
      isMounted = false;
      window.clearTimeout(timer);
    };
  }, [tables]);

  const generateRange = async () => {
    if (!venueId || !canManageTables) return;

    const start = Number.parseInt(startRange, 10);
    const end = Number.parseInt(endRange, 10);
    if (
      !Number.isFinite(start) ||
      !Number.isFinite(end) ||
      start < 1 ||
      end < start ||
      end - start > 150
    ) {
      setStatusMessage("Use a valid table range up to 150 tables.");
      return;
    }

    setWorking(true);
    setStatusMessage(null);
    try {
      for (let table = start; table <= end; table += 1) {
        await generateVenueTableQr(venueId, String(table));
      }
      await loadTables();
      setStatusMessage("Table QR codes generated.");
    } catch (err) {
      setStatusMessage(
        err instanceof Error
          ? err.message
          : "Failed to generate table QR codes.",
      );
    } finally {
      setWorking(false);
    }
  };

  const toggleTable = async (table: VenueTable) => {
    setWorking(true);
    setStatusMessage(null);
    try {
      await setVenueTableActive(table.id, !table.isActive);
      await loadTables();
    } catch (err) {
      setStatusMessage(
        err instanceof Error ? err.message : "Failed to update table.",
      );
    } finally {
      setWorking(false);
    }
  };

  const shareTable = async (table: VenueTable) => {
    const qrUrl = safeHref(table.qrUrl);
    if (!qrUrl) return;
    if (navigator.share) {
      await navigator.share({
        title: `${venue?.name ?? "Venue"} table ${table.tableNumber}`,
        url: qrUrl,
      });
      return;
    }
    await navigator.clipboard.writeText(qrUrl);
    setStatusMessage("Table link copied.");
  };

  return (
    <div className="max-w-7xl mx-auto space-y-8">
      <div className="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
        <div>
          <h1 className="text-4xl font-black tracking-tighter">Tables / QR</h1>
          <p className="text-textSecondary font-medium mt-1">
            Secure table links generated from Supabase table tokens.
          </p>
        </div>
        <button
          type="button"
          className="btn btn-secondary w-fit"
          onClick={loadTables}
          disabled={loading}
        >
          <RefreshCcw size={16} className={loading ? "animate-spin" : ""} />
          Refresh
        </button>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-8">
        <aside className="lg:col-span-4 space-y-6">
          <div className="bg-white p-6 rounded-[28px] border border-border shadow-sm">
            <div className="flex items-center gap-3 mb-6">
              <div className="w-10 h-10 bg-primary/5 text-primary rounded-xl flex items-center justify-center">
                <QrCode size={20} />
              </div>
              <div>
                <h2 className="font-black text-xl">Generator</h2>
                <p className="text-sm text-textSecondary font-bold">
                  Owner or manager access
                </p>
              </div>
            </div>

            <div className="space-y-4">
              <div>
                <label className="text-xs font-bold text-textSecondary uppercase tracking-widest mb-2 block">
                  Table range
                </label>
                <div className="flex items-center gap-3">
                  <input
                    type="number"
                    min={1}
                    value={startRange}
                    onChange={(event) => setStartRange(event.target.value)}
                    className="input"
                    disabled={!canManageTables}
                  />
                  <span className="text-textSecondary font-bold">to</span>
                  <input
                    type="number"
                    min={1}
                    value={endRange}
                    onChange={(event) => setEndRange(event.target.value)}
                    className="input"
                    disabled={!canManageTables}
                  />
                </div>
              </div>

              <button
                onClick={generateRange}
                disabled={working || !canManageTables}
                className="btn btn-primary w-full h-14"
              >
                {working ? (
                  <Loader2 size={20} className="animate-spin" />
                ) : (
                  <QrCode size={20} />
                )}
                Generate Codes
              </button>
            </div>
          </div>

          <div className="bg-white p-6 rounded-[28px] border border-border shadow-sm">
            <div className="flex items-center gap-3">
              <ShieldCheck size={20} className="text-success" />
              <p className="text-sm font-bold text-textSecondary">
                QR payloads include venue, table, and server-generated token.
              </p>
            </div>
            {statusMessage && (
              <p className="text-sm font-bold text-text mt-4">
                {statusMessage}
              </p>
            )}
          </div>
        </aside>

        <section className="lg:col-span-8">
          {loading && tables.length === 0 ? (
            <div className="h-[420px] flex items-center justify-center">
              <Loader2 className="animate-spin text-primary" size={42} />
            </div>
          ) : tables.length === 0 ? (
            <EmptyState
              icon={<QrCode size={38} />}
              title="No venue tables yet"
              message="Generate a table range to create secure scan-to-order links."
            />
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              {tables.map((table) => {
                const qrUrl = safeHref(table.qrUrl);
                return (
                  <article
                    key={table.id}
                    className="bg-white p-6 rounded-[28px] border border-border shadow-sm"
                  >
                    <div className="flex justify-between items-start gap-4 mb-5">
                      <div>
                        <p className="text-[10px] font-bold text-textSecondary uppercase tracking-widest">
                          Table
                        </p>
                        <h3 className="text-4xl font-black">
                          {table.tableNumber}
                        </h3>
                      </div>
                      <StatusChip
                        status={table.isActive ? "active" : "inactive"}
                      />
                    </div>

                    <div className="qr-paper aspect-square border border-border rounded-2xl flex items-center justify-center p-4">
                      {qrImages[table.id] ? (
                        <img
                          src={qrImages[table.id]}
                          className="w-full h-full object-contain"
                          alt={`QR code for table ${table.tableNumber}`}
                        />
                      ) : (
                        <QrCode size={64} className="text-textSecondary" />
                      )}
                    </div>

                    <p className="text-[10px] text-textSecondary font-bold truncate w-full text-center mt-4">
                      {table.qrUrl ?? "No active QR link"}
                    </p>

                    <div className="grid grid-cols-2 gap-3 mt-5">
                      <a
                        className="btn btn-secondary"
                        href={qrImages[table.id]}
                        download={`table-${table.tableNumber}-qr.png`}
                        aria-disabled={!qrImages[table.id]}
                      >
                        <Download size={16} />
                        Download
                      </a>
                      <button
                        className="btn btn-secondary"
                        onClick={() => shareTable(table)}
                        disabled={!qrUrl}
                      >
                        <Share2 size={16} />
                        Share
                      </button>
                      <a
                        className="btn btn-secondary"
                        href={qrUrl ?? undefined}
                        target="_blank"
                        rel="noreferrer"
                        aria-disabled={!qrUrl}
                      >
                        <Maximize2 size={16} />
                        Open
                      </a>
                      <button
                        className="btn btn-secondary"
                        onClick={() => toggleTable(table)}
                        disabled={working || !canManageTables}
                      >
                        {table.isActive ? "Deactivate" : "Activate"}
                      </button>
                    </div>
                  </article>
                );
              })}
            </div>
          )}
        </section>
      </div>
    </div>
  );
};
