import React from 'react';
import { View, ActivityIndicator } from 'react-native';
import { useColors } from '../src/hooks/useColors';

/** Entry route. The navigation gate in _layout redirects based on auth state. */
export default function Index() {
  const { colors } = useColors();
  return (
    <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.bg }}>
      <ActivityIndicator size="large" color={colors.primary} />
    </View>
  );
}
