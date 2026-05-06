import { resolveConfiguredTestOtp } from "./index.ts";

// ── Google Play reviewer phone: +250788767816 / OTP: 123456 ──

const futureExpiry = "2999-01-01T00:00:00Z";

Deno.test("resolveConfiguredTestOtp returns OTP for exact match (Google Play reviewer)", () => {
  const otp = resolveConfiguredTestOtp(
    "+250788767816",
    "+250788767816",
    "123456",
    futureExpiry,
  );
  if (otp !== "123456") {
    throw new Error("Expected Google Play reviewer phone to resolve to 123456");
  }
});

Deno.test("resolveConfiguredTestOtp normalizes spaces/dashes in input phone", () => {
  const withSpaces = resolveConfiguredTestOtp(
    "+250 788 767 816",
    "+250788767816",
    "123456",
    futureExpiry,
  );
  if (withSpaces !== "123456") {
    throw new Error("Expected spaced phone to still match");
  }

  const withDashes = resolveConfiguredTestOtp(
    "+250-788-767-816",
    "+250788767816",
    "123456",
    futureExpiry,
  );
  if (withDashes !== "123456") {
    throw new Error("Expected dashed phone to still match");
  }
});

Deno.test("resolveConfiguredTestOtp normalizes configured phone too", () => {
  const otp = resolveConfiguredTestOtp(
    "+250788767816",
    "+250 788 767 816",
    "123456",
    futureExpiry,
  );
  if (otp !== "123456") {
    throw new Error("Expected configured phone with spaces to still match");
  }
});

Deno.test("resolveConfiguredTestOtp returns the configured OTP for Malta test phone", () => {
  const otp = resolveConfiguredTestOtp(
    "+356 9971 1145",
    "+35699711145",
    "123456",
    futureExpiry,
  );
  if (otp !== "123456") {
    throw new Error(
      "Expected Malta reviewer phone to resolve to the configured OTP",
    );
  }
});

Deno.test("resolveConfiguredTestOtp rejects non-matching phone", () => {
  const result = resolveConfiguredTestOtp(
    "+250788000000",
    "+250788767816",
    "123456",
    futureExpiry,
  );
  if (result !== null) {
    throw new Error("Expected non-matching phone to return null");
  }
});

Deno.test("resolveConfiguredTestOtp rejects invalid OTP format (non-6-digit)", () => {
  const alpha = resolveConfiguredTestOtp(
    "+250788767816",
    "+250788767816",
    "abc123",
    futureExpiry,
  );
  const short = resolveConfiguredTestOtp(
    "+250788767816",
    "+250788767816",
    "1234",
    futureExpiry,
  );
  const long = resolveConfiguredTestOtp(
    "+250788767816",
    "+250788767816",
    "1234567",
    futureExpiry,
  );

  if (alpha !== null) throw new Error("Expected alpha OTP to be rejected");
  if (short !== null) throw new Error("Expected short OTP to be rejected");
  if (long !== null) throw new Error("Expected long OTP to be rejected");
});

Deno.test("resolveConfiguredTestOtp handles empty/null config gracefully", () => {
  const emptyPhone = resolveConfiguredTestOtp("+250788767816", "", "123456");
  const nullPhone = resolveConfiguredTestOtp("+250788767816", null, "123456");
  const emptyOtp = resolveConfiguredTestOtp(
    "+250788767816",
    "+250788767816",
    "",
  );
  const nullOtp = resolveConfiguredTestOtp(
    "+250788767816",
    "+250788767816",
    null,
  );
  const undefinedBoth = resolveConfiguredTestOtp(
    "+250788767816",
    undefined,
    undefined,
  );

  if (emptyPhone !== null) {
    throw new Error("Empty phone config should return null");
  }
  if (nullPhone !== null) {
    throw new Error("Null phone config should return null");
  }
  if (emptyOtp !== null) throw new Error("Empty OTP config should return null");
  if (nullOtp !== null) throw new Error("Null OTP config should return null");
  if (undefinedBoth !== null) {
    throw new Error("Undefined config should return null");
  }
});

Deno.test("resolveConfiguredTestOtp requires a valid future expiry", () => {
  const missingExpiry = resolveConfiguredTestOtp(
    "+250788767816",
    "+250788767816",
    "123456",
    "",
  );
  const expired = resolveConfiguredTestOtp(
    "+250788767816",
    "+250788767816",
    "123456",
    "2020-01-01T00:00:00Z",
  );
  const invalid = resolveConfiguredTestOtp(
    "+250788767816",
    "+250788767816",
    "123456",
    "not-a-date",
  );

  if (missingExpiry !== null) {
    throw new Error("Missing expiry should disable fixed reviewer OTP");
  }
  if (expired !== null) {
    throw new Error("Expired fixed reviewer OTP should be rejected");
  }
  if (invalid !== null) {
    throw new Error("Invalid fixed reviewer expiry should be rejected");
  }
});
