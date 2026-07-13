import React from 'react';
import { View, Text } from 'react-native';
import { useRouter } from 'expo-router';
import { ArrowLeft, LifeBuoy } from 'lucide-react-native';

import { Screen } from '../../src/components/ui/Screen';
import { Button } from '../../src/components/ui/Button';
import { useColors } from '../../src/hooks/useColors';
import { font, fontSize, radius, spacing } from '../../src/lib/theme';

/**
 * Sem transporte de e-mail configurado no backend de autenticação
 * compartilhado, não há mais reset de senha self-service por e-mail (o
 * Firebase Authentication nativo não é mais usado para login aqui). Um
 * administrador master pode redefinir a senha pelo painel Empresa.
 */
export default function Recovery() {
  const { colors } = useColors();
  const router = useRouter();

  return (
    <Screen contentStyle={{ flexGrow: 1, gap: spacing.md }}>
      <Button
        variant="ghost"
        size="sm"
        fullWidth={false}
        label="Voltar"
        icon={<ArrowLeft size={18} color={colors.textMuted} />}
        onPress={() => router.back()}
        style={{ alignSelf: 'flex-start' }}
      />
      <Text style={{ color: colors.text, fontWeight: font.black, fontSize: fontSize['3xl'] }}>
        Recuperar senha
      </Text>

      <View
        style={{
          backgroundColor: colors.primarySoft,
          borderRadius: radius.md,
          padding: spacing.md,
          borderWidth: 2,
          borderColor: colors.primary,
          flexDirection: 'row',
          gap: spacing.sm,
          alignItems: 'flex-start',
        }}
      >
        <LifeBuoy size={20} color={colors.primaryDark} />
        <Text style={{ color: colors.primaryDark, fontWeight: font.semibold, flex: 1 }}>
          Fale com o suporte da Nexmarket informando seu e-mail cadastrado. Um
          administrador vai redefinir sua senha.
        </Text>
      </View>
    </Screen>
  );
}
