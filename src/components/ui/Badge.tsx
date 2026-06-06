import React from 'react';
import { View, Text } from 'react-native';
import { radius, font, fontSize } from '../../lib/theme';

interface BadgeProps {
  label: string;
  fg: string;
  bg: string;
  icon?: React.ReactNode;
}

export function Badge({ label, fg, bg, icon }: BadgeProps) {
  return (
    <View
      style={{
        flexDirection: 'row',
        alignItems: 'center',
        alignSelf: 'flex-start',
        backgroundColor: bg,
        paddingHorizontal: 10,
        paddingVertical: 4,
        borderRadius: radius.full,
        gap: 4,
      }}
    >
      {icon}
      <Text
        style={{
          color: fg,
          fontWeight: font.bold,
          fontSize: fontSize.xs,
          textTransform: 'uppercase',
          letterSpacing: 0.4,
        }}
      >
        {label}
      </Text>
    </View>
  );
}

import { palette } from '../../lib/theme';
import type { Order } from '../../lib/types';

const DELIVERY_LABELS: Record<string, { label: string; fg: string; bg: string }> = {
  awaiting_driver: { label: 'Disponível', fg: '#92400E', bg: palette.amberSoft },
  going_to_store: { label: 'A caminho da loja', fg: '#1E40AF', bg: palette.blueSoft },
  arrived_store: { label: 'Na loja', fg: '#1E40AF', bg: palette.blueSoft },
  picked_up: { label: 'Coletado', fg: '#3730A3', bg: palette.indigoSoft },
  going_to_customer: { label: 'A caminho do cliente', fg: '#3730A3', bg: palette.indigoSoft },
  delivered: { label: 'Entregue', fg: '#166534', bg: palette.greenSoft },
  problem: { label: 'Problema', fg: '#991B1B', bg: palette.redSoft },
};

export function deliveryBadge(order: Order) {
  const key = order.deliveryStatus || (order.status === 'delivered' ? 'delivered' : '');
  return (
    DELIVERY_LABELS[key] || {
      label: order.status,
      fg: palette.slate600,
      bg: palette.slate100,
    }
  );
}
