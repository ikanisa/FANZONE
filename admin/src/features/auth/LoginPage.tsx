// FANZONE Admin — Login Page
import { useMemo, useRef, useState } from "react";
import { Loader, MessageCircle } from "lucide-react";

import {
  FanzoneWordmark,
  renderFanzoneText,
} from "../../components/FanzoneWordmark";
import { useAuth } from "../../hooks/useAuth";

const logoImg = "/brand/logo-mark-128.png";

type LoginStep = "phone" | "otp";

const OTP_LENGTH = 6;

function normalizePhone(rawPhone: string) {
  const trimmed = rawPhone.trim();
  if (!trimmed) return "";

  const digits = trimmed.replace(/\D/g, "");
  return trimmed.startsWith("+") ? `+${digits}` : digits;
}

function isValidPhone(rawPhone: string) {
  const normalized = normalizePhone(rawPhone);
  const digits = normalized.replace(/\D/g, "");
  return normalized.startsWith("+") && digits.length >= 8;
}

export function LoginPage() {
  const { requestOtp, verifyOtp, isLoading, error } = useAuth();
  const [step, setStep] = useState<LoginStep>("phone");
  const [phone, setPhone] = useState("");
  const [sentPhone, setSentPhone] = useState("");
  const [otp, setOtp] = useState<string[]>(() => Array(OTP_LENGTH).fill(""));
  const otpRefs = useRef<Array<HTMLInputElement | null>>([]);

  const normalizedPhone = useMemo(() => normalizePhone(phone), [phone]);
  const canRequestOtp = isValidPhone(phone) && !isLoading;
  const canVerifyOtp = otp.join("").length === OTP_LENGTH && !isLoading;

  const handleRequestOtp = async (event: React.FormEvent) => {
    event.preventDefault();
    if (!canRequestOtp) return;

    const sent = await requestOtp(normalizedPhone);
    if (!sent) return;
    setSentPhone(normalizedPhone);
    setOtp(Array(OTP_LENGTH).fill(""));
    setStep("otp");
  };

  const handleVerifyOtp = async (event: React.FormEvent) => {
    event.preventDefault();
    if (!canVerifyOtp || !sentPhone) return;
    await verifyOtp(sentPhone, otp.join(""));
  };

  const handleOtpChange = (index: number, value: string) => {
    const digit = value.replace(/\D/g, "").slice(-1);
    setOtp((current) => {
      const next = [...current];
      next[index] = digit;
      return next;
    });

    if (digit && index < OTP_LENGTH - 1) {
      otpRefs.current[index + 1]?.focus();
    }
  };

  const handleOtpKeyDown = (
    index: number,
    event: React.KeyboardEvent<HTMLInputElement>,
  ) => {
    if (event.key === "Backspace" && !otp[index] && index > 0) {
      otpRefs.current[index - 1]?.focus();
    }
  };

  const goBackToPhone = () => {
    setStep("phone");
    setOtp(Array(OTP_LENGTH).fill(""));
  };

  return (
    <div className="login-page">
      <div className="login-card">
        <div className="login-brand">
          <img src={logoImg} alt="FANZONE" className="login-logo" />
          <h1 className="login-title">
            <FanzoneWordmark />
          </h1>
          <p className="login-subtitle">Admin Console</p>
        </div>

        <form
          className="login-form"
          onSubmit={step === "phone" ? handleRequestOtp : handleVerifyOtp}
        >
          {error && (
            <div className="login-error">{renderFanzoneText(error)}</div>
          )}

          {step === "phone" ? (
            <>
              <div className="login-step-header">
                <MessageCircle size={22} />
                <h2>VERIFY VIA WHATSAPP</h2>
              </div>

              <p className="login-step-copy">
                {renderFanzoneText(
                  "Use your provisioned WhatsApp number to access the FANZONE admin console.",
                )}
              </p>

              <div className="field-group">
                <label className="label" htmlFor="login-phone">
                  WhatsApp Number
                </label>
                <input
                  id="login-phone"
                  type="tel"
                  className="input"
                  placeholder="+356 99 123 456"
                  value={phone}
                  onChange={(event) => setPhone(event.target.value)}
                  autoComplete="tel"
                  autoFocus
                  required
                />
              </div>

              <button
                type="submit"
                className="btn btn-primary w-full btn-lg"
                disabled={!canRequestOtp}
              >
                {isLoading ? (
                  <Loader size={18} className="spin" />
                ) : (
                  "Send Code Via WhatsApp"
                )}
              </button>
            </>
          ) : (
            <>
              <div className="login-step-header">
                <MessageCircle size={22} />
                <h2>ENTER OTP</h2>
              </div>

              <p className="login-step-copy">
                Enter the 6-digit code sent to <strong>{sentPhone}</strong> on
                WhatsApp.
              </p>

              <div className="otp-grid" aria-label="WhatsApp verification code">
                {otp.map((digit, index) => (
                  <input
                    key={index}
                    ref={(node) => {
                      otpRefs.current[index] = node;
                    }}
                    className="otp-input"
                    type="text"
                    inputMode="numeric"
                    autoComplete={index === 0 ? "one-time-code" : "off"}
                    maxLength={1}
                    value={digit}
                    onChange={(event) =>
                      handleOtpChange(index, event.target.value)
                    }
                    onKeyDown={(event) => handleOtpKeyDown(index, event)}
                    aria-label={`OTP digit ${index + 1}`}
                    autoFocus={index === 0}
                  />
                ))}
              </div>

              <button
                type="submit"
                className="btn btn-primary w-full btn-lg"
                disabled={!canVerifyOtp}
              >
                {isLoading ? (
                  <Loader size={18} className="spin" />
                ) : (
                  "Verify Code"
                )}
              </button>

              <button
                type="button"
                className="login-secondary"
                onClick={goBackToPhone}
                disabled={isLoading}
              >
                Use another WhatsApp number
              </button>
            </>
          )}
        </form>

        <p className="login-footer">
          {renderFanzoneText("FANZONE Malta — Internal Use Only")}
        </p>
      </div>

      <style>{`
        .login-page {
          min-height: 100vh;
          display: flex;
          align-items: center;
          justify-content: center;
          background: var(--fz-bg);
          padding: var(--fz-sp-6);
        }
        .login-card {
          width: 100%;
          max-width: 400px;
          background: var(--fz-surface);
          border: 1px solid var(--fz-border);
          border-radius: var(--fz-radius-xl);
          padding: var(--fz-sp-10);
        }
        .login-brand {
          text-align: center;
          margin-bottom: var(--fz-sp-8);
        }
        .login-logo {
          width: 64px;
          height: 64px;
          border-radius: var(--fz-radius-lg);
          object-fit: contain;
          margin: 0 auto var(--fz-sp-4);
        }
        .login-title {
          font-size: var(--fz-text-2xl);
          font-weight: 800;
          letter-spacing: 0.06em;
          color: var(--fz-text);
        }
        .login-subtitle {
          font-size: var(--fz-text-sm);
          color: var(--fz-muted);
          margin-top: var(--fz-sp-1);
        }
        .login-form {
          display: flex;
          flex-direction: column;
          gap: var(--fz-sp-5);
        }
        .login-step-header {
          display: flex;
          align-items: center;
          gap: var(--fz-sp-3);
          color: var(--fz-accent);
        }
        .login-step-header h2 {
          margin: 0;
          font-size: var(--fz-text-lg);
          font-weight: 800;
          letter-spacing: 0.08em;
          color: inherit;
        }
        .login-step-copy {
          margin: 0;
          font-size: var(--fz-text-sm);
          line-height: 1.6;
          color: var(--fz-muted);
        }
        .login-error {
          background: var(--fz-error-bg);
          color: var(--fz-error);
          padding: var(--fz-sp-3) var(--fz-sp-4);
          border-radius: var(--fz-radius);
          font-size: var(--fz-text-sm);
          border: 1px solid rgba(239,68,68,0.2);
        }
        .login-info {
          background: rgba(152, 255, 152, 0.12);
          color: var(--fz-text);
          padding: var(--fz-sp-3) var(--fz-sp-4);
          border-radius: var(--fz-radius);
          font-size: var(--fz-text-sm);
          border: 1px solid rgba(152, 255, 152, 0.2);
        }
        .otp-grid {
          display: grid;
          grid-template-columns: repeat(6, minmax(0, 1fr));
          gap: var(--fz-sp-2);
        }
        .otp-input {
          width: 100%;
          height: 52px;
          text-align: center;
          border-radius: var(--fz-radius);
          border: 1px solid var(--fz-border);
          background: var(--fz-surface-2);
          color: var(--fz-text);
          font-size: var(--fz-text-xl);
          font-weight: 700;
        }
        .otp-input:focus {
          outline: none;
          border-color: var(--fz-accent);
          box-shadow: 0 0 0 1px color-mix(in srgb, var(--fz-accent) 35%, transparent);
        }
        .login-secondary {
          border: 0;
          background: transparent;
          color: var(--fz-muted);
          font-size: var(--fz-text-xs);
          font-weight: 700;
          cursor: pointer;
        }
        .login-secondary:disabled {
          opacity: 0.6;
          cursor: not-allowed;
        }
        .login-footer {
          text-align: center;
          font-size: var(--fz-text-xs);
          color: var(--fz-muted-2);
          margin-top: var(--fz-sp-8);
        }
        .spin { animation: spin 1s linear infinite; }
        @keyframes spin { to { transform: rotate(360deg); } }
      `}</style>
    </div>
  );
}
