import * as Location from 'expo-location';
import * as TaskManager from 'expo-task-manager';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { doc, updateDoc, serverTimestamp } from 'firebase/firestore';
import { db } from './firebase';

/**
 * Location tracking, tuned for battery & privacy.
 *
 * Privacy: tracking is only ever started while the driver is Online or on an
 * active delivery (callers enforce this) and is stopped on going Offline.
 * Battery: we use Balanced accuracy, a 50m distance filter and a 15s interval,
 * plus deferred updates, so the GPS isn't hammered.
 */

const BG_TASK = 'nex-bg-location';
const KEY_DRIVER = '@nex_active_driver';
const KEY_ORDER = '@nex_active_order';

async function writeLocation(lat: number, lng: number) {
  const driverId = await AsyncStorage.getItem(KEY_DRIVER);
  if (!driverId) return;
  const point = { lat, lng, updatedAt: serverTimestamp() };

  try {
    await updateDoc(doc(db, `drivers/${driverId}`), {
      location: point,
      updatedAt: serverTimestamp(),
    });
  } catch (e) {
    console.warn('bg driver location write failed', e);
  }

  // Mirror onto the active order so the store can track the driver live.
  const orderRaw = await AsyncStorage.getItem(KEY_ORDER);
  if (orderRaw) {
    try {
      const { smId, orderId } = JSON.parse(orderRaw);
      if (smId && orderId) {
        await updateDoc(doc(db, `supermarkets/${smId}/orders/${orderId}`), {
          driverLocation: point,
          updatedAt: serverTimestamp(),
        });
      }
    } catch (e) {
      console.warn('bg order location write failed', e);
    }
  }
}

// Background task definition (must be registered at module load).
TaskManager.defineTask(BG_TASK, async ({ data, error }) => {
  if (error) {
    console.warn('bg location task error', error.message);
    return;
  }
  const locs = (data as any)?.locations as Location.LocationObject[] | undefined;
  const last = locs?.[locs.length - 1];
  if (last) {
    await writeLocation(last.coords.latitude, last.coords.longitude);
  }
});

export async function requestLocationPermissions(): Promise<{
  foreground: boolean;
  background: boolean;
}> {
  const fg = await Location.requestForegroundPermissionsAsync();
  let background = false;
  if (fg.status === 'granted') {
    try {
      const bg = await Location.requestBackgroundPermissionsAsync();
      background = bg.status === 'granted';
    } catch {
      background = false;
    }
  }
  return { foreground: fg.status === 'granted', background };
}

export async function getCurrentPosition(): Promise<{ lat: number; lng: number } | null> {
  try {
    const fg = await Location.getForegroundPermissionsAsync();
    if (fg.status !== 'granted') {
      const r = await Location.requestForegroundPermissionsAsync();
      if (r.status !== 'granted') return null;
    }
    const pos = await Location.getCurrentPositionAsync({
      accuracy: Location.Accuracy.Balanced,
    });
    return { lat: pos.coords.latitude, lng: pos.coords.longitude };
  } catch {
    return null;
  }
}

/** Start sharing location for the given driver. */
export async function startTracking(driverId: string) {
  await AsyncStorage.setItem(KEY_DRIVER, driverId);
  const perms = await requestLocationPermissions();
  if (!perms.foreground) return false;

  // Immediate one-shot so the dot appears right away.
  const now = await getCurrentPosition();
  if (now) await writeLocation(now.lat, now.lng);

  if (perms.background) {
    const already = await Location.hasStartedLocationUpdatesAsync(BG_TASK).catch(
      () => false,
    );
    if (!already) {
      await Location.startLocationUpdatesAsync(BG_TASK, {
        accuracy: Location.Accuracy.Balanced,
        timeInterval: 15000,
        distanceInterval: 50,
        deferredUpdatesInterval: 30000,
        deferredUpdatesDistance: 80,
        pausesUpdatesAutomatically: true,
        foregroundService: {
          notificationTitle: 'Nexmarket Entregador',
          notificationBody: 'Compartilhando localização enquanto você está Online.',
          notificationColor: '#58CC02',
        },
      });
    }
  }
  return true;
}

export async function stopTracking() {
  await AsyncStorage.removeItem(KEY_DRIVER);
  await AsyncStorage.removeItem(KEY_ORDER);
  try {
    const started = await Location.hasStartedLocationUpdatesAsync(BG_TASK);
    if (started) await Location.stopLocationUpdatesAsync(BG_TASK);
  } catch {}
}

/** Tell the tracker which order to mirror location onto (or clear it). */
export async function setActiveOrder(smId: string | null, orderId: string | null) {
  if (smId && orderId) {
    await AsyncStorage.setItem(KEY_ORDER, JSON.stringify({ smId, orderId }));
  } else {
    await AsyncStorage.removeItem(KEY_ORDER);
  }
}
