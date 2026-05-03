import { useState, type FormEvent } from "react";
import { useVenueAuth } from "../../hooks/useVenueAuth";

export function VenueLoginPage() {
  const { requestOtp, verifyOtp, isLoading, error } = useVenueAuth();
  const [phone, setPhone] = useState("");
  const [sentPhone, setSentPhone] = useState("");
  const [otp, setOtp] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleSend = async (event: FormEvent) => {
    event.preventDefault();
    setIsSubmitting(true);
    const sent = await requestOtp(phone);
    if (sent) {
      setSentPhone(phone);
      setOtp("");
    }
    setIsSubmitting(false);
  };

  const handleVerify = async (event: FormEvent) => {
    event.preventDefault();
    if (otp.length !== 6) return;
    setIsSubmitting(true);
    await verifyOtp(sentPhone || phone, otp);
    setIsSubmitting(false);
  };

  return (
    <main className="min-h-screen bg-bg text-text flex items-center justify-center p-6">
      <section className="w-full max-w-md rounded-[28px] border border-border bg-surface p-8 shadow-2xl shadow-black/30">
        <p className="text-xs font-black uppercase tracking-widest text-primary">
          Venue Console
        </p>
        <h1 className="mt-3 text-3xl font-black tracking-tight">
          Sign in with WhatsApp
        </h1>
        <p className="mt-3 text-sm leading-6 text-textSecondary font-bold">
          Staff access uses the same WhatsApp OTP session as FANZONE admin.
        </p>

        <form className="mt-8 space-y-4" onSubmit={sentPhone ? handleVerify : handleSend}>
          <label className="block">
            <span className="text-xs font-black uppercase tracking-widest text-textSecondary">
              WhatsApp phone
            </span>
            <input
              className="mt-2 min-h-14 w-full rounded-2xl border border-border bg-surface2 px-4 font-black text-text outline-none focus:border-primary"
              value={phone}
              onChange={(event) => setPhone(event.target.value)}
              placeholder="+356 ..."
              autoComplete="tel"
              disabled={Boolean(sentPhone)}
            />
          </label>

          {sentPhone && (
            <label className="block">
              <span className="text-xs font-black uppercase tracking-widest text-textSecondary">
                OTP code
              </span>
              <input
                className="mt-2 min-h-14 w-full rounded-2xl border border-border bg-surface2 px-4 text-center text-2xl font-black tracking-[0.35em] text-text outline-none focus:border-primary"
                value={otp}
                onChange={(event) => setOtp(event.target.value.replace(/\D/g, "").slice(0, 6))}
                placeholder="000000"
                inputMode="numeric"
                autoComplete="one-time-code"
              />
            </label>
          )}

          {error && (
            <p className="rounded-2xl border border-danger/30 bg-danger/10 px-4 py-3 text-sm font-bold text-danger">
              {error}
            </p>
          )}

          <button
            type="submit"
            disabled={isSubmitting || isLoading || !phone || (Boolean(sentPhone) && otp.length !== 6)}
            className="min-h-14 w-full rounded-2xl bg-primary px-5 font-black text-primaryText disabled:cursor-not-allowed disabled:opacity-50"
          >
            {sentPhone ? "VERIFY OTP" : "SEND OTP"}
          </button>

          {sentPhone && (
            <button
              type="button"
              onClick={() => {
                setSentPhone("");
                setOtp("");
              }}
              className="min-h-12 w-full rounded-2xl bg-surface2 px-5 font-black text-textSecondary"
            >
              CHANGE PHONE
            </button>
          )}
        </form>
      </section>
    </main>
  );
}
