import React, { useMemo } from 'react';
import { View, Text, Pressable } from 'react-native';
import { useRouter } from 'expo-router';
import { Store, MapPin, Package, ChevronRight, Clock } from 'lucide-react-native';

import { Screen } from '../../src/components/ui/Screen';
import { Card } from '../../src/components/ui/Card';
import { Badge, deliveryBadge } from '../../src/components/ui/Badge';
import { useColors } from '../../src/hooks/useColors';
import { font, fontSize, spacing } from '../../src/lib/theme';
import { brl, formatDateTime, fullAddress } from '../../src/lib/format';
import { useDriverStore } from '../../src/store/useDriverStore';
import { isActiveDelivery } from '../../src/lib/orders';
import type { Order } from '../../src/lib/types';

export default function Deliveries() {
  const { colors } = useColors();
  const myDeliveries = useDriverStore((s) => s.myDeliveries);

  const { active, history } = useMemo(() => {
    const active = myDeliveries.filter(isActiveDelivery);
    const history = myDeliveries.filter((o) => !isActiveDelivery(o));
    return { active, history };
  }, [myDeliveries]);

  return (
    <Screen title="Entregas" subtitle="Acompanhe suas corridas">
      {active.length > 0 ? (
        <Section colors={colors} title="Em andamento">
          {active.map((o) => (
            <DeliveryRow key={o.id} order={o} colors={colors} navigable />
          ))}
        </Section>
      ) : null}

      <Section colors={colors} title="Histórico">
        {history.length === 0 ? (
          <Card>
            <View style={{ alignItems: 'center', paddingVertical: spacing.lg }}>
              <Package size={40} color={colors.textSubtle} />
              <Text style={{ color: colors.textMuted, fontWeight: font.bold, marginTop: 8 }}>
                Nenhuma entrega ainda
              </Text>
              <Text style={{ color: colors.textSubtle, fontWeight: font.medium, fontSize: fontSize.sm }}>
                Suas entregas concluídas aparecerão aqui.
              </Text>
            </View>
          </Card>
        ) : (
          history.map((o) => <DeliveryRow key={o.id} order={o} colors={colors} />)
        )}
      </Section>
    </Screen>
  );
}

function Section({ colors, title, children }: { colors: any; title: string; children: React.ReactNode }) {
  return (
    <View style={{ gap: spacing.md }}>
      <Text style={{ color: colors.text, fontWeight: font.black, fontSize: fontSize.lg }}>{title}</Text>
      {children}
    </View>
  );
}

function DeliveryRow({ order, colors, navigable }: { order: Order; colors: any; navigable?: boolean }) {
  const router = useRouter();
  const badge = deliveryBadge(order);
  const earnings = order.driverEarnings || 0;

  const content = (
    <Card>
      <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
        <Badge label={badge.label} fg={badge.fg} bg={badge.bg} />
        <Text style={{ color: colors.primaryDark, fontWeight: font.black, fontSize: fontSize.lg }}>
          {brl(earnings)}
        </Text>
      </View>
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}>
        <Store size={15} color={colors.accent} />
        <Text style={{ color: colors.text, fontWeight: font.bold, flex: 1 }} numberOfLines={1}>
          {order.storeName || 'Loja'}
        </Text>
      </View>
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6, marginTop: 4 }}>
        <MapPin size={15} color={colors.danger} />
        <Text style={{ color: colors.textMuted, fontWeight: font.medium, fontSize: fontSize.sm, flex: 1 }} numberOfLines={1}>
          {fullAddress(order.deliveryAddress)}
        </Text>
      </View>
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6, marginTop: 6, justifyContent: 'space-between' }}>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}>
          <Clock size={13} color={colors.textSubtle} />
          <Text style={{ color: colors.textSubtle, fontWeight: font.medium, fontSize: fontSize.xs }}>
            {formatDateTime(order.deliveredAt || order.acceptedAt) || '—'}
          </Text>
        </View>
        {navigable ? <ChevronRight size={18} color={colors.textMuted} /> : null}
      </View>
    </Card>
  );

  if (navigable) {
    return (
      <Pressable onPress={() => router.push(`/delivery/${order.id}?sm=${order.supermarketId}`)}>
        {content}
      </Pressable>
    );
  }
  return content;
}
