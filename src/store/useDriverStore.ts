import { create } from 'zustand';
import type { DriverProfile, Order } from '../lib/types';

interface AuthUser {
  uid: string;
  email: string | null;
  isAnonymous: boolean;
}

interface DriverState {
  authUser: AuthUser | null;
  authReady: boolean;
  driver: DriverProfile | null;

  available: Order[];
  myDeliveries: Order[];

  // The offer currently being presented to the driver (modal).
  pendingOfferId: string | null;
  declinedIds: string[];

  setAuthUser: (u: AuthUser | null) => void;
  setAuthReady: (v: boolean) => void;
  setDriver: (d: DriverProfile | null) => void;
  setAvailable: (o: Order[]) => void;
  setMyDeliveries: (o: Order[]) => void;
  setPendingOffer: (id: string | null) => void;
  decline: (id: string) => void;
  reset: () => void;
}

export const useDriverStore = create<DriverState>((set) => ({
  authUser: null,
  authReady: false,
  driver: null,
  available: [],
  myDeliveries: [],
  pendingOfferId: null,
  declinedIds: [],

  setAuthUser: (authUser) => set({ authUser }),
  setAuthReady: (authReady) => set({ authReady }),
  setDriver: (driver) => set({ driver }),
  setAvailable: (available) => set({ available }),
  setMyDeliveries: (myDeliveries) => set({ myDeliveries }),
  setPendingOffer: (pendingOfferId) => set({ pendingOfferId }),
  decline: (id) =>
    set((s) => ({ declinedIds: [...s.declinedIds, id], pendingOfferId: null })),
  reset: () =>
    set({
      driver: null,
      available: [],
      myDeliveries: [],
      pendingOfferId: null,
      declinedIds: [],
    }),
}));

/** Selector: the driver's single in-progress delivery, if any. */
export const selectActiveDelivery = (s: DriverState): Order | null => {
  const active = s.myDeliveries.find(
    (o) =>
      o.deliveryStatus &&
      ['assigned', 'going_to_store', 'arrived_store', 'picked_up', 'going_to_customer', 'problem'].includes(
        o.deliveryStatus,
      ),
  );
  return active ?? null;
};
