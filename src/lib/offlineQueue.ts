import AsyncStorage from '@react-native-async-storage/async-storage';
import { doc, updateDoc, serverTimestamp } from 'firebase/firestore';
import { db } from './firebase';
import { isOnline } from './net';

/**
 * Offline-first action queue.
 *
 * Critical writes (confirming a pickup, completing a delivery, sending proof
 * of delivery) are persisted locally and replayed automatically once the
 * connection returns — so the driver is never blocked by a flaky signal.
 */

const QUEUE_KEY = '@nex_offline_queue_v1';

export interface OrderUpdateTask {
  id: string;
  type: 'orderUpdate';
  smId: string;
  orderId: string;
  data: Record<string, any>;
  createdAt: number;
}

type Task = OrderUpdateTask;

async function readQueue(): Promise<Task[]> {
  try {
    const raw = await AsyncStorage.getItem(QUEUE_KEY);
    return raw ? (JSON.parse(raw) as Task[]) : [];
  } catch {
    return [];
  }
}

async function writeQueue(tasks: Task[]) {
  await AsyncStorage.setItem(QUEUE_KEY, JSON.stringify(tasks));
}

export async function getQueueSize(): Promise<number> {
  return (await readQueue()).length;
}

async function enqueue(task: Task) {
  const q = await readQueue();
  q.push(task);
  await writeQueue(q);
}

async function executeTask(task: Task): Promise<void> {
  if (task.type === 'orderUpdate') {
    const ref = doc(db, `supermarkets/${task.smId}/orders/${task.orderId}`);
    await updateDoc(ref, { ...task.data, updatedAt: serverTimestamp() });
  }
}

/**
 * Try a Firestore order update immediately. If offline (or it fails), the
 * write is queued and will sync later. Resolves to `true` when it was applied
 * online right away, `false` when it was queued for later.
 */
export async function resilientOrderUpdate(
  smId: string,
  orderId: string,
  data: Record<string, any>,
): Promise<boolean> {
  const task: OrderUpdateTask = {
    id: `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
    type: 'orderUpdate',
    smId,
    orderId,
    data,
    createdAt: Date.now(),
  };

  if (!isOnline()) {
    await enqueue(task);
    return false;
  }

  try {
    await executeTask(task);
    return true;
  } catch (e) {
    console.warn('Order update failed, queued for retry', e);
    await enqueue(task);
    return false;
  }
}

let flushing = false;

/** Replay every queued task. Safe to call repeatedly. */
export async function flushQueue(): Promise<void> {
  if (flushing || !isOnline()) return;
  flushing = true;
  try {
    let q = await readQueue();
    const remaining: Task[] = [];
    for (const task of q) {
      try {
        await executeTask(task);
      } catch (e) {
        console.warn('Flush task failed, keeping in queue', e);
        remaining.push(task);
      }
    }
    await writeQueue(remaining);
  } finally {
    flushing = false;
  }
}
