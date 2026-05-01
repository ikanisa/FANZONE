import { buildOffPlatformPaymentHandoff } from "./off_platform_payment.ts";

Deno.test("buildOffPlatformPaymentHandoff creates MoMo merchant USSD handoff", () => {
  const handoff = buildOffPlatformPaymentHandoff(
    "momo",
    { countryCode: "RW", momoCode: " 123-456 " },
    { totalAmount: 1250.25, currencyCode: "RWF" },
  );

  if (handoff.ussd_string !== "*182*8*1*123456#") {
    throw new Error(`Unexpected USSD string: ${handoff.ussd_string}`);
  }

  if (handoff.payment_status !== "pending" || handoff.auto_confirms_payment) {
    throw new Error("Expected off-platform handoff to keep payment pending");
  }

  if (!handoff.requires_staff_confirmation) {
    throw new Error("Expected staff confirmation to be required");
  }
});

Deno.test("buildOffPlatformPaymentHandoff uses unchanged Revolut links", () => {
  const handoff = buildOffPlatformPaymentHandoff(
    "revolut",
    { countryCode: "MT", revolutLink: "revolut.me/examplevenue" },
    { totalAmount: 19.5, currencyCode: "EUR" },
  );

  if (handoff.payment_url !== "https://revolut.me/examplevenue") {
    throw new Error(`Unexpected Revolut link: ${handoff.payment_url}`);
  }

  if (handoff.amount !== "19.50") {
    throw new Error(`Unexpected amount: ${handoff.amount}`);
  }
});

Deno.test("buildOffPlatformPaymentHandoff rejects MoMo without venue payment details", () => {
  let rejected = false;
  try {
    buildOffPlatformPaymentHandoff(
      "momo",
      { countryCode: "RW" },
      { totalAmount: 1000, currencyCode: "RWF" },
    );
  } catch {
    rejected = true;
  }

  if (!rejected) {
    throw new Error(
      "Expected MoMo handoff without code or phone to be rejected",
    );
  }
});
