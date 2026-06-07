import 'react-native-gesture-handler';
import React, { useEffect, useState, useCallback } from 'react';
import { View, ActivityIndicator } from 'react-native';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { StatusBar } from 'expo-status-bar';
import { Stack, useRouter, useSegments } from 'expo-router';
import { onAuthStateChanged } from 'firebase/auth';
import * as SplashScreen from 'expo-splash-screen';

import { auth } from '../src/lib/firebase';
import { subscribeDriver } from '../src/lib/drivers';
import {
  subscribeAvailableOrders,
  subscribeMyDeliveries,
  acceptOrder,
} from '../src/lib/orders';
import { useDriverStore, selectActiveDelivery } from '../src/store/useDriverStore';
import { useColors } from '../src/hooks/useColors';
import { startNetWatcher } from '../src/lib/net';
import { flushQueue } from '../src/lib/offlineQueue';
import { ensureNotificationPermissions, alertNewOffer } from '../src/lib/notifications';
import { setActiveOrder } from '../src/lib/location';
import { OfferModal } from '../src/components/OfferModal';
import { brl } from '../src/lib/format';
// Registers the background location task on load.
import '../src/lib/location';

SplashScreen.preventAutoHideAsync().catch(() => {});

function RootNav() {
  const { colors } = useColors();
  const router = useRouter();
  const segments = useSegments();

  const {
    authUser,
    authReady,
    driver,
    available,
    setAuthUser,
    setAuthReady,
    setDriver,
    setAvailable,
    setMyDeliveries,
    pendingOfferId,
    setPendingOffer,
    decline,
    declinedIds,
    myDeliveries,
  } = useDriverStore();

  const [driverLoaded, setDriverLoaded] = useState(false);
  const [accepting, setAccepting] = useState(false);
  const activeDelivery = selectActiveDelivery(useDriverStore());

  /* ---- auth listener ---- */
  useEffect(() => {
    const unsub = onAuthStateChanged(auth, (u) => {
      setAuthUser(u ? { uid: u.uid, email: u.email, isAnonymous: u.isAnonymous } : null);
      setAuthReady(true);
    });
    ensureNotificationPermissions().catch(() => {});
    const stopNet = startNetWatcher(() => flushQueue());
    return () => {
      unsub();
      stopNet();
    };
  }, []);

  /* ---- driver profile subscription ---- */
  useEffect(() => {
    if (!authUser) {
      setDriver(null);
      setDriverLoaded(true);
      return;
    }
    setDriverLoaded(false);
    const unsub = subscribeDriver(authUser.uid, (d) => {
      setDriver(d);
      setDriverLoaded(true);
    });
    return unsub;
  }, [authUser?.uid]);

  /* ---- live order subscriptions ---- */
  useEffect(() => {
    if (!authUser || !driver) return;
    const unsubA = subscribeAvailableOrders(setAvailable);
    const unsubM = subscribeMyDeliveries(authUser.uid, setMyDeliveries);
    return () => {
      unsubA();
      unsubM();
    };
  }, [authUser?.uid, !!driver]);

  /* ---- keep tracker pointed at the active delivery ---- */
  useEffect(() => {
    if (activeDelivery) {
      setActiveOrder(activeDelivery.supermarketId, activeDelivery.id);
    } else {
      setActiveOrder(null, null);
    }
  }, [activeDelivery?.id]);

  /* ---- offer selection ---- */
  useEffect(() => {
    if (!driver || driver.status !== 'online' || activeDelivery) {
      if (pendingOfferId) setPendingOffer(null);
      return;
    }
    if (pendingOfferId) {
      // Clear if the pending offer was taken by someone else.
      if (!available.find((o) => o.id === pendingOfferId)) setPendingOffer(null);
      return;
    }
    const next = available.find(
      (o) => !declinedIds.includes(o.id) && o.driverId !== authUser?.uid,
    );
    if (next) {
      setPendingOffer(next.id);
      alertNewOffer({
        store: next.storeName || 'Loja',
        earnings: brl(next.deliveryFee || 0),
        sound: driver.preferences?.soundAlerts !== false,
      });
    }
  }, [available, driver?.status, activeDelivery?.id, pendingOfferId, declinedIds]);

  /* ---- navigation gate ---- */
  useEffect(() => {
    if (!authReady) return;
    const group = segments[0] as string | undefined;
    const inAuth = group === '(auth)';
    const inOnboarding = group === 'onboarding';

    if (!authUser) {
      if (!inAuth) router.replace('/(auth)/login');
      return;
    }
    if (!driverLoaded) return;
    if (!driver) {
      if (!inOnboarding) router.replace('/onboarding');
      return;
    }
    // Authenticated with a profile: make sure we're inside the app tabs
    // (covers the initial index route, auth and onboarding groups).
    if (group !== '(tabs)' && group !== 'delivery' && group !== 'chat') {
      router.replace('/(tabs)');
    }
  }, [authReady, authUser, driver, driverLoaded, segments]);

  /* ---- hide splash when ready ---- */
  useEffect(() => {
    if (authReady) SplashScreen.hideAsync().catch(() => {});
  }, [authReady]);

  const pendingOrder = available.find((o) => o.id === pendingOfferId) || null;

  const onAccept = useCallback(
    async (order: typeof pendingOrder) => {
      if (!order || !driver) return;
      setAccepting(true);
      try {
        await acceptOrder(order, driver);
        setPendingOffer(null);
        router.push(`/delivery/${order.id}?sm=${order.supermarketId}`);
      } catch (e: any) {
        decline(order.id);
        // The offer effect will surface the next available order.
        console.warn('accept failed', e?.message);
      } finally {
        setAccepting(false);
      }
    },
    [driver],
  );

  const gateLoading =
    !authReady || (!!authUser && !driverLoaded);

  return (
    <>
      <StatusBar style="auto" />
      <Stack screenOptions={{ headerShown: false, contentStyle: { backgroundColor: colors.bg } }}>
        <Stack.Screen name="(auth)" />
        <Stack.Screen name="onboarding" />
        <Stack.Screen name="(tabs)" />
        <Stack.Screen name="delivery/[id]" />
        <Stack.Screen name="chat/[id]" options={{ presentation: 'modal' }} />
      </Stack>

      {gateLoading ? (
        <View
          style={{
            position: 'absolute',
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            backgroundColor: colors.bg,
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <ActivityIndicator size="large" color={colors.primary} />
        </View>
      ) : null}

      <OfferModal
        order={pendingOrder}
        driverLocation={driver?.location}
        accepting={accepting}
        onAccept={onAccept}
        onDecline={(o) => decline(o.id)}
      />
    </>
  );
}

export default function RootLayout() {
  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <SafeAreaProvider>
        <RootNav />
      </SafeAreaProvider>
    </GestureHandlerRootView>
  );
}
