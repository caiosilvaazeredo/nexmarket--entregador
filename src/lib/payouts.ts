import {
  collection,
  addDoc,
  query,
  orderBy,
  onSnapshot,
  serverTimestamp,
} from 'firebase/firestore';
import { db } from './firebase';
import { debitBalance } from './drivers';
import type { Payout } from './types';

function payoutsCol(uid: string) {
  return collection(db, `drivers/${uid}/payouts`);
}

export function subscribePayouts(uid: string, cb: (p: Payout[]) => void) {
  const q = query(payoutsCol(uid), orderBy('createdAt', 'desc'));
  return onSnapshot(
    q,
    (snap) => cb(snap.docs.map((d) => ({ id: d.id, ...(d.data() as any) } as Payout))),
    (err) => {
      console.warn('subscribePayouts error', err);
      cb([]);
    },
  );
}

/** Request a withdrawal of `amount` to the given destination (e.g. PIX key). */
export async function requestPayout(
  uid: string,
  amount: number,
  method: string,
  destination: string,
) {
  await addDoc(payoutsCol(uid), {
    amount,
    method,
    destination,
    status: 'requested',
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });
  await debitBalance(uid, amount);
}
