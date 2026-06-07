import {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  onSnapshot,
  serverTimestamp,
  increment,
} from 'firebase/firestore';
import { db } from './firebase';
import type { DriverProfile, DriverPreferences, Vehicle, BankInfo } from './types';

export const defaultPreferences: DriverPreferences = {
  soundAlerts: true,
  darkMode: false,
  navApp: 'google',
};

export const defaultVehicle: Vehicle = {
  type: 'moto',
  plate: '',
  model: '',
};

export function driverRef(uid: string) {
  return doc(db, `drivers/${uid}`);
}

export async function getDriver(uid: string): Promise<DriverProfile | null> {
  const snap = await getDoc(driverRef(uid));
  return snap.exists() ? ({ uid, ...(snap.data() as any) } as DriverProfile) : null;
}

export function subscribeDriver(
  uid: string,
  cb: (d: DriverProfile | null) => void,
) {
  return onSnapshot(
    driverRef(uid),
    (snap) => cb(snap.exists() ? ({ uid, ...(snap.data() as any) } as DriverProfile) : null),
    (err) => {
      console.warn('subscribeDriver error', err);
      cb(null);
    },
  );
}

export async function createDriverProfile(
  uid: string,
  data: {
    name: string;
    email: string;
    phone: string;
    vehicle?: Partial<Vehicle>;
    photoUrl?: string;
  },
): Promise<void> {
  const profile = {
    name: data.name,
    email: data.email,
    phone: data.phone || '',
    photoUrl: data.photoUrl || '',
    status: 'offline',
    vehicle: { ...defaultVehicle, ...(data.vehicle || {}) },
    documents: { status: 'pending' },
    bank: {},
    preferences: defaultPreferences,
    location: null,
    rating: 5,
    totalDeliveries: 0,
    balance: 0,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  };
  await setDoc(driverRef(uid), profile, { merge: true });
}

export async function updateDriverProfile(
  uid: string,
  partial: Partial<DriverProfile>,
): Promise<void> {
  await updateDoc(driverRef(uid), {
    ...partial,
    updatedAt: serverTimestamp(),
  });
}

export async function updateVehicle(uid: string, vehicle: Vehicle) {
  await updateDriverProfile(uid, { vehicle });
}

export async function updateBank(uid: string, bank: BankInfo) {
  await updateDriverProfile(uid, { bank });
}

export async function updatePreferences(
  uid: string,
  preferences: DriverPreferences,
) {
  await updateDriverProfile(uid, { preferences });
}

export async function setOnlineStatus(uid: string, online: boolean) {
  await updateDriverProfile(uid, { status: online ? 'online' : 'offline' });
}

export async function addEarnings(uid: string, amount: number) {
  await updateDoc(driverRef(uid), {
    balance: increment(amount),
    totalDeliveries: increment(1),
    updatedAt: serverTimestamp(),
  });
}

export async function debitBalance(uid: string, amount: number) {
  await updateDoc(driverRef(uid), {
    balance: increment(-Math.abs(amount)),
    updatedAt: serverTimestamp(),
  });
}
