import React, { useEffect, useRef, useState } from 'react';
import { Modal, View, Text, Animated, Easing } from 'react-native';
import { Store, MapPin, Navigation, Package, Clock } from 'lucide-react-native';
import { useColors } from '../hooks/useColors';
import { Button } from './ui/Button';
import { radius, font, fontSize, spacing, shadow } from '../lib/theme';
import { brl, formatDistance, fullAddress } from '../lib/format';
import { offerDistances, estimateEarnings } from '../lib/orders';
import type { Order, GeoPoint } from '../lib/types';

interface OfferModalProps {
  order: Order | null;
  driverLocation?: GeoPoint | null;
  accepting?: boolean;
  onAccept: (o: Order) => void;
  onDecline: (o: Order) => void;
  durationMs?: number;
}

export function OfferModal({
  order,
  driverLocation,
  accepting,
  onAccept,
  onDecline,
  durationMs = 30000,
}: OfferModalProps) {
  const { colors } = useColors();
  const progress = useRef(new Animated.Value(1)).current;
  const [secondsLeft, setSecondsLeft] = useState(Math.round(durationMs / 1000));

  useEffect(() => {
    if (!order) return;
    setSecondsLeft(Math.round(durationMs / 1000));
    progress.setValue(1);

    Animated.timing(progress, {
      toValue: 0,
      duration: durationMs,
      easing: Easing.linear,
      useNativeDriver: false,
    }).start();

    const tick = setInterval(() => {
      setSecondsLeft((s) => Math.max(0, s - 1));
    }, 1000);

    const timeout = setTimeout(() => onDecline(order), durationMs);

    return () => {
      clearInterval(tick);
      clearTimeout(timeout);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [order?.id]);

  if (!order) return null;

  const { toStore, storeToCustomer } = offerDistances(order, driverLocation);
  const earnings = estimateEarnings(order, storeToCustomer ?? undefined);
  const widthInterp = progress.interpolate({
    inputRange: [0, 1],
    outputRange: ['0%', '100%'],
  });

  return (
    <Modal visible transparent animationType="slide" onRequestClose={() => onDecline(order)}>
      <View style={{ flex: 1, backgroundColor: colors.overlay, justifyContent: 'flex-end' }}>
        <View
          style={[
            {
              backgroundColor: colors.card,
              borderTopLeftRadius: radius['2xl'],
              borderTopRightRadius: radius['2xl'],
              padding: spacing.xl,
              paddingBottom: spacing['2xl'],
            },
            shadow.raised,
          ]}
        >
          {/* countdown bar */}
          <View
            style={{
              height: 6,
              borderRadius: 3,
              backgroundColor: colors.border,
              overflow: 'hidden',
              marginBottom: spacing.md,
            }}
          >
            <Animated.View
              style={{ height: 6, width: widthInterp, backgroundColor: colors.primary }}
            />
          </View>

          <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' }}>
            <Text style={{ color: colors.text, fontWeight: font.black, fontSize: fontSize['2xl'] }}>
              Nova entrega!
            </Text>
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 4 }}>
              <Clock size={16} color={colors.danger} />
              <Text style={{ color: colors.danger, fontWeight: font.black, fontSize: fontSize.lg }}>
                {secondsLeft}s
              </Text>
            </View>
          </View>

          {/* earnings highlight */}
          <View
            style={{
              backgroundColor: colors.primarySoft,
              borderRadius: radius.lg,
              padding: spacing.md,
              marginTop: spacing.md,
              alignItems: 'center',
            }}
          >
            <Text style={{ color: colors.textMuted, fontWeight: font.semibold, fontSize: fontSize.xs }}>
              GANHO ESTIMADO
            </Text>
            <Text style={{ color: colors.primaryDark, fontWeight: font.black, fontSize: fontSize['4xl'] }}>
              {brl(earnings)}
            </Text>
          </View>

          {/* route rows */}
          <View style={{ marginTop: spacing.lg, gap: spacing.md }}>
            <Row
              icon={<Store size={18} color={colors.accent} />}
              title={order.storeName || 'Loja'}
              sub={`Coleta • ${toStore != null ? formatDistance(toStore) + ' de você' : 'distância indisponível'}`}
              colors={colors}
            />
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6, paddingLeft: 8 }}>
              <Navigation size={14} color={colors.textSubtle} />
              <Text style={{ color: colors.textSubtle, fontWeight: font.medium, fontSize: fontSize.xs }}>
                {storeToCustomer != null
                  ? `${formatDistance(storeToCustomer)} até o cliente`
                  : 'Trajeto loja → cliente'}
              </Text>
            </View>
            <Row
              icon={<MapPin size={18} color={colors.danger} />}
              title={order.customerName || 'Cliente'}
              sub={fullAddress(order.deliveryAddress)}
              colors={colors}
            />
          </View>

          {/* items summary */}
          <View
            style={{
              flexDirection: 'row',
              alignItems: 'center',
              gap: 6,
              marginTop: spacing.md,
              marginBottom: spacing.lg,
            }}
          >
            <Package size={16} color={colors.textMuted} />
            <Text style={{ color: colors.textMuted, fontWeight: font.semibold, flex: 1 }}>
              {order.items?.length || 0} itens • {order.items?.slice(0, 2).map((i) => i.name).join(', ')}
              {order.items && order.items.length > 2 ? '…' : ''}
            </Text>
          </View>

          <Button label="Aceitar entrega" size="lg" loading={accepting} onPress={() => onAccept(order)} />
          <View style={{ height: spacing.sm }} />
          <Button label="Recusar" variant="ghost" onPress={() => onDecline(order)} />
        </View>
      </View>
    </Modal>
  );
}

function Row({
  icon,
  title,
  sub,
  colors,
}: {
  icon: React.ReactNode;
  title: string;
  sub: string;
  colors: any;
}) {
  return (
    <View style={{ flexDirection: 'row', alignItems: 'flex-start', gap: 10 }}>
      <View
        style={{
          width: 36,
          height: 36,
          borderRadius: radius.md,
          backgroundColor: colors.cardMuted,
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        {icon}
      </View>
      <View style={{ flex: 1 }}>
        <Text style={{ color: colors.text, fontWeight: font.bold, fontSize: fontSize.base }}>{title}</Text>
        <Text style={{ color: colors.textMuted, fontWeight: font.medium, fontSize: fontSize.sm }}>{sub}</Text>
      </View>
    </View>
  );
}
