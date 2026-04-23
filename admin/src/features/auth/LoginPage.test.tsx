// @vitest-environment jsdom
import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

import { AuthContext, type AuthState } from "../../hooks/auth-context";
import { LoginPage } from "./LoginPage";

function buildAuthState(overrides: Partial<AuthState> = {}): AuthState {
  return {
    session: null,
    admin: null,
    isLoading: false,
    error: null,
    requestOtp: async () => true,
    verifyOtp: async () => true,
    signOut: async () => {},
    ...overrides,
  };
}

describe("LoginPage", () => {
  it("exposes WhatsApp OTP login only", () => {
    render(
      <AuthContext.Provider value={buildAuthState()}>
        <LoginPage />
      </AuthContext.Provider>,
    );

    expect(screen.getByText("VERIFY VIA WHATSAPP")).toBeTruthy();
    expect(screen.getByLabelText("WhatsApp Number")).toBeTruthy();
    expect(screen.queryByLabelText("Email")).toBeNull();
    expect(screen.queryByLabelText("Password")).toBeNull();
  });

  it("moves to OTP verification after sending a WhatsApp code", async () => {
    const requestOtp = vi.fn().mockResolvedValue(true);

    render(
      <AuthContext.Provider value={buildAuthState({ requestOtp })}>
        <LoginPage />
      </AuthContext.Provider>,
    );

    fireEvent.change(screen.getByLabelText("WhatsApp Number"), {
      target: { value: "+111 9912 3456" },
    });
    const submitButton = screen.getByRole("button", {
      name: "Send Code Via WhatsApp",
    }) as HTMLButtonElement;

    await waitFor(() => {
      expect(submitButton.disabled).toBe(false);
    });

    fireEvent.submit(submitButton.closest("form")!);

    await waitFor(
      () => {
        expect(requestOtp).toHaveBeenCalledWith("+11199123456");
      },
      { timeout: 10000 },
    );
    await waitFor(
      () => {
        expect(screen.getByText("ENTER OTP")).toBeTruthy();
      },
      { timeout: 10000 },
    );
  });
});
