import { resolveConfiguredTestOtp } from "./index.ts";

Deno.test("resolveConfiguredTestOtp returns the configured OTP for the reviewer phone", () => {
  const otp = resolveConfiguredTestOtp(
    "+356 9971 1145",
    "+35699711145",
    "123456",
  );

  if (otp !== "123456") {
    throw new Error("Expected reviewer phone to resolve to the configured OTP");
  }
});

Deno.test("resolveConfiguredTestOtp rejects invalid or non-matching reviewer config", () => {
  const wrongPhone = resolveConfiguredTestOtp(
    "+35699112233",
    "+35699711145",
    "123456",
  );
  const invalidOtp = resolveConfiguredTestOtp(
    "+35699711145",
    "+35699711145",
    "abc123",
  );

  if (wrongPhone !== null) {
    throw new Error("Expected non-matching phone to reject reviewer OTP");
  }

  if (invalidOtp !== null) {
    throw new Error("Expected invalid reviewer OTP config to be ignored");
  }
});
