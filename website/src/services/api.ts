import { type Match, type FanClub, type Pool } from '../types';
import { mockMatches, mockFanClubs, mockPools } from '../lib/mockData';

// Simulate network latency
const delay = (ms: number) => new Promise(res => setTimeout(res, ms));

export const api = {
  // Matches
  async getLiveMatches(): Promise<Match[]> {
    await delay(600);
    return mockMatches.filter(m => m.status === 'live');
  },
  async getUpcomingMatches(): Promise<Match[]> {
    await delay(600);
    return mockMatches.filter(m => m.status === 'upcoming');
  },
  
  // Predictions
  async submitPredictionSlip(slipData: any): Promise<{ success: boolean; slipId: string }> {
    await delay(1200);
    // Real implementation will post `slipData` to backend here
    return { success: true, slipId: 'slip_' + Math.random().toString(36).substring(7) };
  },

  // Social & Fan Clubs
  async getFanClubs(): Promise<FanClub[]> {
    await delay(600);
    return mockFanClubs;
  },
  async getPendingPools(): Promise<Pool[]> {
    await delay(600);
    return mockPools.filter(c => c.status === 'pending');
  },
  async createPool(targetId: string, matchId: string, wager: number): Promise<boolean> {
    await delay(800);
    // Create logic
    return true;
  },

  // Auth & User
  async requestOtp(phone: string): Promise<boolean> {
    await delay(1000);
    return true;
  },
  async verifyOtp(phone: string, otp: string): Promise<{ token: string; user: any }> {
    await delay(1000);
    if (otp.length === 6) {
      return { token: 'mock_token', user: { id: 'u1', phone, isVerified: true } };
    }
    throw new Error("Invalid OTP");
  }
};
