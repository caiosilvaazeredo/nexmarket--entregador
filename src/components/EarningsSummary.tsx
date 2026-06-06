import React, { useMemo } from 'react';
import { View, Text } from 'react-native';
import { Card } from './ui/Card';
import { useColors } from '../hooks/useColors';
import { font, fontSize, spacing } from '../lib/theme';
import { brl, toDate } from '../lib/format';
import type { Order } from '../lib/types';
import { TrendingUp, Package } from 'lucide-react-native';

function startOfToday() {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  return d;
}
function startOfWeek() {
  const d = startOfToday();
  const day = (d.getDay() + 6) % 7; // Monday = 0
  d.setDate(d.getDate() - day);
  return d;
}

export function summarize(orders: Order[]) {
  const delivered = orders.filter((o) => o.deliveryStatus === 'delivered' || o.status === 'delivered');
  const today = startOfToday().getTime();
  const week = startOfWeek().getTime();
  let todayEarn = 0,
    weekEarn = 0,
    todayCount = 0,
    weekCount = 0;
  for (const o of delivered) {
    const t = toDate(o.deliveredAt)?.getTime() ?? 0;
    const e = o.driverEarnings || 0;
    if (t >= today) {
      todayEarn += e;
      todayCount += 1;
    }
    if (t >= week) {
      weekEarn += e;
      weekCount += 1;
    }
  }
  return { todayEarn, weekEarn, todayCount, weekCount, total: delivered.length };
}

export function EarningsSummary({ orders }: { orders: Order[] }) {
  const { colors } = useColors();
  const s = useMemo(() => summarize(orders), [orders]);

  return (
    <Card elevated>
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: spacing.md }}>
        <TrendingUp size={20} color={colors.primary} />
        <Text style={{ color: colors.text, fontWeight: font.black, fontSize: fontSize.lg }}>
          Seus ganhos
        </Text>
      </View>
      <View style={{ flexDirection: 'row', gap: spacing.md }}>
        <Stat label="Hoje" value={brl(s.todayEarn)} sub={`${s.todayCount} entregas`} colors={colors} />
        <View style={{ width: 1, backgroundColor: colors.border }} />
        <Stat label="Esta semana" value={brl(s.weekEarn)} sub={`${s.weekCount} entregas`} colors={colors} />
      </View>
    </Card>
  );
}

function Stat({
  label,
  value,
  sub,
  colors,
}: {
  label: string;
  value: string;
  sub: string;
  colors: any;
}) {
  return (
    <View style={{ flex: 1 }}>
      <Text style={{ color: colors.textMuted, fontWeight: font.semibold, fontSize: fontSize.xs }}>
        {label.toUpperCase()}
      </Text>
      <Text style={{ color: colors.text, fontWeight: font.black, fontSize: fontSize['2xl'], marginTop: 2 }}>
        {value}
      </Text>
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 4, marginTop: 2 }}>
        <Package size={12} color={colors.textSubtle} />
        <Text style={{ color: colors.textSubtle, fontWeight: font.medium, fontSize: fontSize.xs }}>
          {sub}
        </Text>
      </View>
    </View>
  );
}
