import React from 'react';
import { Pressable, View, Text, ActivityIndicator } from 'react-native';
import { Power } from 'lucide-react-native';
import { useColors } from '../hooks/useColors';
import { radius, font, fontSize, shadow } from '../lib/theme';

interface OnlineToggleProps {
  online: boolean;
  loading?: boolean;
  onPress: () => void;
}

/** Big, high-contrast, one-hand reachable Online/Offline control. */
export function OnlineToggle({ online, loading, onPress }: OnlineToggleProps) {
  const { colors } = useColors();
  const bg = online ? colors.primary : colors.card;
  const fg = online ? '#FFFFFF' : colors.text;

  return (
    <Pressable
      onPress={onPress}
      disabled={loading}
      style={({ pressed }) => [
        {
          backgroundColor: bg,
          borderRadius: radius['2xl'],
          borderWidth: online ? 0 : 2,
          borderColor: colors.border,
          borderBottomWidth: online ? 5 : 2,
          borderBottomColor: online ? colors.primaryDark : colors.border,
          padding: 18,
          flexDirection: 'row',
          alignItems: 'center',
          gap: 14,
          transform: [{ translateY: pressed ? 2 : 0 }],
        },
        online && shadow.card,
      ]}
    >
      <View
        style={{
          width: 52,
          height: 52,
          borderRadius: radius.full,
          backgroundColor: online ? 'rgba(255,255,255,0.2)' : colors.cardMuted,
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        {loading ? <ActivityIndicator color={fg} /> : <Power size={26} color={fg} strokeWidth={3} />}
      </View>
      <View style={{ flex: 1 }}>
        <Text style={{ color: fg, fontWeight: font.black, fontSize: fontSize.xl }}>
          {online ? 'Você está Online' : 'Você está Offline'}
        </Text>
        <Text
          style={{
            color: online ? 'rgba(255,255,255,0.85)' : colors.textMuted,
            fontWeight: font.medium,
            marginTop: 2,
          }}
        >
          {online ? 'Recebendo pedidos. Toque para parar.' : 'Toque para começar a receber pedidos.'}
        </Text>
      </View>
    </Pressable>
  );
}
