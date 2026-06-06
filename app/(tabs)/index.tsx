import React, { useState, useCallback } from 'react';
import { View, Text, Pressable, Image, Alert } from 'react-native';
import { useRouter } from 'expo-router';
import {
  Store,
  MapPin,
  ChevronRight,
  PackageCheck,
  AlertTriangle,
  Navigation2,
  WifiOff,
} from 'lucide-react-native';

import { Screen } from '../../src/components/ui/Screen';
import { Card } from '../../src/components/ui/Card';
import { Button } from '../../src/components/ui/Button';
import { OnlineToggle } from '../../src/components/OnlineToggle';
import { EarningsSummary } from '../../src/components/EarningsSummary';
import { MapPanel } from '../../src/components/MapPanel';
import { useColors } from '../../src/hooks/useColors';
import { font, fontSize, radius, spacing } from '../../src/lib/theme';
import { brl, formatDistance, fullAddress } from '../../src/lib/format';
import { useDriverStore, selectActiveDelivery } from '../../src/store/useDriverStore';
import { setOnlineStatus } from '../../src/lib/drivers';
import {
  startTracking,
  stopTracking,
  requestLocationPermissions,
  getCurrentPosition,
} from '../../src/lib/location';
import { isValidGeo, regionFor } from '../../src/lib/geo';
import { offerDistances, estimateEarnings } from '../../src/lib/orders';
import { useNet } from '../../src/lib/net';
import type { Order } from '../../src/lib/types';

export default function Home() {
  const { colors } = useColors();
  const router = useRouter();
  const driver = useDriverStore((s) => s.driver);
  const available = useDriverStore((s) => s.available);
  const myDeliveries = useDriverStore((s) => s.myDeliveries);
  const setPendingOffer = useDriverStore((s) => s.setPendingOffer);
  const declinedIds = useDriverStore((s) => s.declinedIds);
  const active = selectActiveDelivery(useDriverStore());
  const isOnline = useNet((s) => s.isOnline);
  const [toggling, setToggling] = useState(false);

  const online = driver?.status === 'online' || driver?.status === 'on_delivery';

  const toggle = useCallback(async () => {
    if (!driver) return;
    setToggling(true);
    try {
      if (!online) {
        const perms = await requestLocationPermissions();
        if (!perms.foreground) {
          Alert.alert(
            'Permissão necessária',
            'Para ficar Online e receber entregas, permita o acesso à sua localização.',
          );
          return;
        }
        await setOnlineStatus(driver.uid, true);
        await startTracking(driver.uid);
        await getCurrentPosition();
      } else {
        await setOnlineStatus(driver.uid, false);
        await stopTracking();
      }
    } catch (e) {
      console.warn(e);
    } finally {
      setToggling(false);
    }
  }, [driver, online]);

  const region =
    driver?.location && isValidGeo(driver.location)
      ? regionFor({ lat: driver.location.lat, lng: driver.location.lng })
      : undefined;

  const visibleOffers = available.filter((o) => !declinedIds.includes(o.id));

  return (
    <Screen
      title={`Olá, ${(driver?.name || 'Entregador').split(' ')[0]} 👋`}
      subtitle={online ? 'Pronto para rodar' : 'Você está fora do ar'}
      right={
        driver?.photoUrl ? (
          <Image source={{ uri: driver.photoUrl }} style={{ width: 44, height: 44, borderRadius: 22 }} />
        ) : (
          <View
            style={{
              width: 44,
              height: 44,
              borderRadius: 22,
              backgroundColor: colors.primarySoft,
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <Text style={{ color: colors.primaryDark, fontWeight: font.black }}>
              {(driver?.name || 'E')[0].toUpperCase()}
            </Text>
          </View>
        )
      }
    >
      {!isOnline ? (
        <View
          style={{
            flexDirection: 'row',
            alignItems: 'center',
            gap: 8,
            backgroundColor: colors.amberSoft,
            padding: spacing.md,
            borderRadius: radius.md,
          }}
        >
          <WifiOff size={18} color={colors.amber} />
          <Text style={{ color: colors.text, fontWeight: font.semibold, flex: 1 }}>
            Sem conexão. Suas ações serão salvas e sincronizadas automaticamente.
          </Text>
        </View>
      ) : null}

      {driver?.documents?.status === 'pending' ? (
        <View
          style={{
            flexDirection: 'row',
            alignItems: 'center',
            gap: 8,
            backgroundColor: colors.blueSoft,
            padding: spacing.md,
            borderRadius: radius.md,
          }}
        >
          <AlertTriangle size={18} color={colors.blue} />
          <Text style={{ color: colors.text, fontWeight: font.semibold, flex: 1 }}>
            Documentos em análise. Você já pode receber entregas de teste.
          </Text>
        </View>
      ) : null}

      <OnlineToggle online={!!online} loading={toggling} onPress={toggle} />

      {active ? (
        <Pressable onPress={() => router.push(`/delivery/${active.id}?sm=${active.supermarketId}`)}>
          <Card elevated style={{ borderColor: colors.primary }}>
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}>
              <View
                style={{
                  width: 44,
                  height: 44,
                  borderRadius: radius.md,
                  backgroundColor: colors.primarySoft,
                  alignItems: 'center',
                  justifyContent: 'center',
                }}
              >
                <Navigation2 size={22} color={colors.primaryDark} />
              </View>
              <View style={{ flex: 1 }}>
                <Text style={{ color: colors.textMuted, fontWeight: font.bold, fontSize: fontSize.xs }}>
                  ENTREGA EM ANDAMENTO
                </Text>
                <Text style={{ color: colors.text, fontWeight: font.black, fontSize: fontSize.lg }}>
                  {active.storeName || 'Loja'} → {active.customerName || 'Cliente'}
                </Text>
              </View>
              <ChevronRight size={22} color={colors.textMuted} />
            </View>
            <Button label="Continuar entrega" style={{ marginTop: spacing.md }} onPress={() => router.push(`/delivery/${active.id}?sm=${active.supermarketId}`)} />
          </Card>
        </Pressable>
      ) : null}

      <EarningsSummary orders={myDeliveries} />

      <MapPanel region={region} height={200} />

      {/* Available offers */}
      {online && !active ? (
        <View style={{ gap: spacing.md }}>
          <Text style={{ color: colors.text, fontWeight: font.black, fontSize: fontSize.lg }}>
            Pedidos disponíveis {visibleOffers.length > 0 ? `(${visibleOffers.length})` : ''}
          </Text>
          {visibleOffers.length === 0 ? (
            <Card>
              <View style={{ alignItems: 'center', paddingVertical: spacing.lg }}>
                <PackageCheck size={40} color={colors.textSubtle} />
                <Text style={{ color: colors.textMuted, fontWeight: font.bold, marginTop: 8 }}>
                  Nenhum pedido por perto
                </Text>
                <Text style={{ color: colors.textSubtle, fontWeight: font.medium, fontSize: fontSize.sm }}>
                  Avisaremos assim que surgir uma entrega.
                </Text>
              </View>
            </Card>
          ) : (
            visibleOffers.map((o) => (
              <OfferRow key={o.id} order={o} driverLoc={driver?.location} onPress={() => setPendingOffer(o.id)} colors={colors} />
            ))
          )}
        </View>
      ) : null}

      <View style={{ height: 8 }} />
    </Screen>
  );
}

function OfferRow({
  order,
  driverLoc,
  onPress,
  colors,
}: {
  order: Order;
  driverLoc: any;
  onPress: () => void;
  colors: any;
}) {
  const { toStore, storeToCustomer } = offerDistances(order, driverLoc);
  const earnings = estimateEarnings(order, storeToCustomer ?? undefined);
  return (
    <Pressable onPress={onPress}>
      <Card>
        <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-start' }}>
          <View style={{ flex: 1, gap: 6 }}>
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}>
              <Store size={16} color={colors.accent} />
              <Text style={{ color: colors.text, fontWeight: font.bold }}>{order.storeName || 'Loja'}</Text>
            </View>
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}>
              <MapPin size={14} color={colors.danger} />
              <Text style={{ color: colors.textMuted, fontWeight: font.medium, fontSize: fontSize.sm, flex: 1 }} numberOfLines={1}>
                {fullAddress(order.deliveryAddress)}
              </Text>
            </View>
            <Text style={{ color: colors.textSubtle, fontWeight: font.medium, fontSize: fontSize.xs }}>
              {order.items?.length || 0} itens
              {toStore != null ? ` • ${formatDistance(toStore)} até a loja` : ''}
            </Text>
          </View>
          <View style={{ alignItems: 'flex-end' }}>
            <Text style={{ color: colors.primaryDark, fontWeight: font.black, fontSize: fontSize.xl }}>
              {brl(earnings)}
            </Text>
            <ChevronRight size={20} color={colors.textMuted} />
          </View>
        </View>
      </Card>
    </Pressable>
  );
}
