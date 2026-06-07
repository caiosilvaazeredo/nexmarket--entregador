import {
  collectionGroup,
  collection,
  query,
  where,
  onSnapshot,
  doc,
  getDoc,
  runTransaction,
  serverTimestamp,
} from 'firebase/firestore';
import { db } from './firebase';
import { resilientOrderUpdate } from './offlineQueue';
import { addEarnings } from './drivers';
import { distanceMeters, isValidGeo } from './geo';
import type {
  Order,
  DriverProfile,
  ProblemType,
  GeoPoint,
} from './types';

/* ----------------------------- Store info cache ----------------------------- */

interface StoreInfo {
  name: string;
  logoUrl?: string;
  location?: GeoPoint | null;
  address?: string;
}

const storeCache = new Map<string, StoreInfo>();

export async function getStoreInfo(smId: string): Promise<StoreInfo> {
  if (storeCache.has(smId)) return storeCache.get(smId)!;
  const info: StoreInfo = { name: 'Loja' };
  try {
    const sm = await getDoc(doc(db, `supermarkets/${smId}`));
    if (sm.exists()) {
      const d = sm.data() as any;
      info.name = d.name || 'Loja';
      info.logoUrl = d.logoUrl;
    }
    const settings = await getDoc(doc(db, `supermarkets/${smId}/settings/storeInfo`));
    if (settings.exists()) {
      const s = settings.data() as any;
      const loc = s.storeLocation || s;
      info.address = loc.address || s.address;
      if (typeof loc.lat === 'number' && typeof loc.lng === 'number') {
        info.location = { lat: loc.lat, lng: loc.lng };
      }
    }
  } catch (e) {
    console.warn('getStoreInfo failed', e);
  }
  storeCache.set(smId, info);
  return info;
}

async function enrich(order: Order): Promise<Order> {
  const info = await getStoreInfo(order.supermarketId);
  return {
    ...order,
    storeName: info.name,
    storeLocation: info.location ?? null,
    storeAddress: info.address,
  };
}

function mapDoc(d: any): Order {
  return { id: d.id, ...(d.data() as any) } as Order;
}

/* ----------------------------- Live queries ----------------------------- */

/** Orders ready for pickup and waiting for any Nexmarket driver. */
export function subscribeAvailableOrders(cb: (orders: Order[]) => void) {
  const q = query(
    collectionGroup(db, 'orders'),
    where('status', '==', 'ready'),
    where('deliveryStatus', '==', 'awaiting_driver'),
  );
  return onSnapshot(
    q,
    async (snap) => {
      const raw = snap.docs.map(mapDoc).filter((o) => !o.driverId);
      const enriched = await Promise.all(raw.map(enrich));
      cb(enriched);
    },
    (err) => {
      console.warn('subscribeAvailableOrders error', err);
      cb([]);
    },
  );
}

/** Every delivery that belongs to this driver (active + history). */
export function subscribeMyDeliveries(uid: string, cb: (orders: Order[]) => void) {
  const q = query(collectionGroup(db, 'orders'), where('driverId', '==', uid));
  return onSnapshot(
    q,
    async (snap) => {
      const raw = snap.docs.map(mapDoc);
      const enriched = await Promise.all(raw.map(enrich));
      enriched.sort((a, b) => ms(b.acceptedAt) - ms(a.acceptedAt));
      cb(enriched);
    },
    (err) => {
      console.warn('subscribeMyDeliveries error', err);
      cb([]);
    },
  );
}

const ms = (ts: any): number => {
  if (!ts) return 0;
  if (typeof ts?.toMillis === 'function') return ts.toMillis();
  if (typeof ts?.seconds === 'number') return ts.seconds * 1000;
  if (typeof ts === 'number') return ts;
  return 0;
};

const ACTIVE_STATUSES = [
  'assigned',
  'going_to_store',
  'arrived_store',
  'picked_up',
  'going_to_customer',
  'problem',
];

export const isActiveDelivery = (o: Order) =>
  !!o.deliveryStatus && ACTIVE_STATUSES.includes(o.deliveryStatus);

export const isFinished = (o: Order) =>
  o.deliveryStatus === 'delivered' || o.status === 'delivered' || o.status === 'cancelled';

/* ----------------------------- Earnings ----------------------------- */

const BASE_FEE = 5;
const PER_KM = 1.5;

export function estimateEarnings(order: Order, storeToCustomerMeters?: number): number {
  if (order.deliveryFee && order.deliveryFee > 0) return order.deliveryFee;
  const km = storeToCustomerMeters ? storeToCustomerMeters / 1000 : 2;
  return Math.max(BASE_FEE, Number((BASE_FEE + km * PER_KM).toFixed(2)));
}

/* ----------------------------- Mutations ----------------------------- */

/**
 * Atomically claim an order. Uses a transaction so two drivers can never
 * grab the same delivery.
 */
export async function acceptOrder(order: Order, driver: DriverProfile): Promise<void> {
  const ref = doc(db, `supermarkets/${order.supermarketId}/orders/${order.id}`);
  await runTransaction(db, async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists()) throw new Error('Pedido não existe mais.');
    const data = snap.data() as any;
    if (data.driverId) throw new Error('Outro entregador já aceitou este pedido.');
    if (data.deliveryStatus !== 'awaiting_driver') {
      throw new Error('Este pedido não está mais disponível.');
    }
    tx.update(ref, {
      driverId: driver.uid,
      driverName: driver.name,
      deliveryStatus: 'going_to_store',
      driverEarnings: estimateEarnings(order),
      acceptedAt: Date.now(),
      updatedAt: serverTimestamp(),
    });
  });
}

export async function arrivedAtStore(order: Order): Promise<boolean> {
  return resilientOrderUpdate(order.supermarketId, order.id, {
    deliveryStatus: 'arrived_store',
  });
}

export async function confirmPickup(order: Order): Promise<boolean> {
  return resilientOrderUpdate(order.supermarketId, order.id, {
    deliveryStatus: 'going_to_customer',
    pickedUpAt: Date.now(),
  });
}

export async function reportProblem(
  order: Order,
  type: ProblemType,
  note?: string,
): Promise<boolean> {
  return resilientOrderUpdate(order.supermarketId, order.id, {
    deliveryStatus: 'problem',
    problemReport: { type, note: note || '', reportedAt: Date.now() },
  });
}

/** Release a delivery back to the pool (driver cancels before delivering). */
export async function releaseOrder(order: Order): Promise<boolean> {
  return resilientOrderUpdate(order.supermarketId, order.id, {
    driverId: '',
    driverName: '',
    deliveryStatus: 'awaiting_driver',
    problemReport: null,
  });
}

/**
 * Finalize a delivery with proof (signature + photo + note). The proof URLs
 * are passed in already-uploaded; the status flip itself is resilient/offline
 * capable so the driver is never blocked from completing a run.
 */
export async function completeDelivery(
  order: Order,
  pod: { signatureUrl?: string; photoUrl?: string; note?: string; receivedBy?: string },
): Promise<boolean> {
  const earnings = order.driverEarnings || estimateEarnings(order);
  const applied = await resilientOrderUpdate(order.supermarketId, order.id, {
    status: 'delivered',
    deliveryStatus: 'delivered',
    deliveredAt: Date.now(),
    proofOfDelivery: {
      signatureUrl: pod.signatureUrl || '',
      photoUrl: pod.photoUrl || '',
      note: pod.note || '',
      receivedBy: pod.receivedBy || '',
    },
    driverEarnings: earnings,
  });
  // Credit the driver wallet (best-effort; safe to retry on next delivery).
  if (order.driverId) {
    try {
      await addEarnings(order.driverId, earnings);
    } catch (e) {
      console.warn('addEarnings failed', e);
    }
  }
  return applied;
}

/* ----------------------------- Distances ----------------------------- */

export function offerDistances(order: Order, driverLoc?: GeoPoint | null) {
  const store = order.storeLocation;
  const cust =
    order.deliveryAddress && isValidGeo(order.deliveryAddress as any)
      ? { lat: order.deliveryAddress.lat!, lng: order.deliveryAddress.lng! }
      : null;

  const toStore =
    isValidGeo(driverLoc) && isValidGeo(store)
      ? distanceMeters(driverLoc!, store!)
      : null;
  const storeToCustomer =
    isValidGeo(store) && cust ? distanceMeters(store!, cust) : null;

  return { toStore, storeToCustomer };
}
