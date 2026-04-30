import { resolveConfiguredTestOtp } from "./index.ts";

// ── Google Play reviewer phone: +250788767816 / OTP: 123456 ──

Deno.test("resolveConfiguredTestOtp returns OTP for exact match (Google Play reviewer)", () => {
  const otp = resolveConfiguredTestOtp(
    "+250788767816",
    "+250788767816",
    "123456",
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
  );
  if (withSpaces !== "123456") {
    throw new Error("Expected spaced phone to still match");
  }

  const withDashes = resolveConfiguredTestOtp(
    "+250-788-767-816",
    "+250788767816",
    "123456",
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
  );
  if (otp !== "123456") {
    throw new Error("Expected Malta reviewer phone to resolve to the configured OTP");
  }
});

Deno.test("resolveConfiguredTestOtp rejects non-matching phone", () => {
  const result = resolveConfiguredTestOtp(
    "+250788000000",
    "+250788767816",
    "123456",
  );
  if (result !== null) {
    throw new Error("Expected non-matching phone to return null");
  }
});

Deno.test("resolveConfiguredTestOtp rejects invalid OTP format (non-6-digit)", () => {
  const alpha = resolveConfiguredTestOtp("+250788767816", "+250788767816", "abc123");
  const short = resolveConfiguredTestOtp("+250788767816", "+250788767816", "1234");
  const long = resolveConfiguredTestOtp("+250788767816", "+250788767816", "1234567");

  if (alpha !== null) throw new Error("Expected alpha OTP to be rejected");
  if (short !== null) throw new Error("Expected short OTP to be rejected");
  if (long !== null) throw new Error("Expected long OTP to be rejected");
});

Deno.test("resolveConfiguredTestOtp handles empty/null config gracefully", () => {
  const emptyPhone = resolveConfiguredTestOtp("+250788767816", "", "123456");
  const nullPhone = resolveConfiguredTestOtp("+250788767816", null, "123456");
  const emptyOtp = resolveConfiguredTestOtp("+250788767816", "+250788767816", "");
  const nullOtp = resolveConfiguredTestOtp("+250788767816", "+250788767816", null);
  const undefinedBoth = resolveConfiguredTestOtp("+250788767816", undefined, undefined);

  if (emptyPhone !== null) throw new Error("Empty phone config should return null");
  if (nullPhone !== null) throw new Error("Null phone config should return null");
  if (emptyOtp !== null) throw new Error("Empty OTP config should return null");
  if (nullOtp !== null) throw new Error("Null OTP config should return null");
  if (undefinedBoth !== null) throw new Error("Undefined config should return null");
});
