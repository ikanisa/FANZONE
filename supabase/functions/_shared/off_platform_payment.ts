export type OffPlatformPaymentMethod = "momo" | "revolut";

export interface OffPlatformVenuePaymentConfig {
  countryCode?: string | null;
  ownerPhone?: string | null;
  whatsapp?: string | null;
  momoCode?: string | null;
  revolutLink?: string | null;
}

export interface OffPlatformOrderPaymentContext {
  totalAmount: number;
  currencyCode?: string | null;
}

export interface OffPlatformPaymentHandoff {
  handoff_type: "external_payment";
  method: OffPlatformPaymentMethod;
  amount: string;
  currency: string;
  payment_status: "pending";
  auto_confirms_payment: false;
  requires_staff_confirmation: true;
  instructions: string[];
  ussd_string?: string;
  payment_url?: string;
}

function digitsOnly(value?: string | null): string {
  return (value || "").replace(/\D/g, "");
}

function amountForCurrency(amount: number, currency: string): string {
  if (currency === "RWF") return String(Math.ceil(amount));
  return amount.toFixed(2);
}

function normalizeRevolutLink(link?: string | null): string | null {
  const trimmed = link?.trim();
  if (!trimmed) return null;
  if (/^https?:\/\//i.test(trimmed)) return trimmed;
  return `https://${trimmed}`;
}

export function buildOffPlatformPaymentHandoff(
  method: OffPlatformPaymentMethod,
  venue: OffPlatformVenuePaymentConfig,
  order: OffPlatformOrderPaymentContext,
): OffPlatformPaymentHandoff {
  const currency = order.currencyCode ||
    (venue.countryCode === "RW" ? "RWF" : "EUR");
  const amount = amountForCurrency(order.totalAmount, currency);

  if (method === "momo") {
    if (venue.countryCode !== "RW") {
      throw new Error("MoMo USSD is only available for Rwanda venues.");
    }

    const momoCode = digitsOnly(venue.momoCode);
    const fallbackPhone = digitsOnly(venue.ownerPhone) ||
      digitsOnly(venue.whatsapp);

    if (!momoCode && !fallbackPhone) {
      throw new Error("Venue does not have a MoMo code or phone configured.");
    }

    const ussdString = momoCode
      ? `*182*8*1*${momoCode}#`
      : `*182*1*1*${fallbackPhone}*${amount}#`;

    return {
      handoff_type: "external_payment",
      method,
      amount,
      currency,
      payment_status: "pending",
      auto_confirms_payment: false,
      requires_staff_confirmation: true,
      ussd_string: ussdString,
      instructions: [
        `Dial ${ussdString}.`,
        `Pay ${amount} ${currency} using the phone menu.`,
        "Show the MoMo confirmation SMS to venue staff so they can mark the order paid.",
      ],
    };
  }

  const paymentUrl = normalizeRevolutLink(venue.revolutLink);
  if (!paymentUrl) {
    throw new Error("Venue does not have a Revolut payment link configured.");
  }

  return {
    handoff_type: "external_payment",
    method,
    amount,
    currency,
    payment_status: "pending",
    auto_confirms_payment: false,
    requires_staff_confirmation: true,
    payment_url: paymentUrl,
    instructions: [
      `Open the venue Revolut link and pay ${amount} ${currency}.`,
      "Show the Revolut confirmation to venue staff so they can mark the order paid.",
    ],
  };
}
