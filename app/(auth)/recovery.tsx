import React, { useState } from 'react';
import { View, Text } from 'react-native';
import { useRouter } from 'expo-router';
import { ArrowLeft, Mail } from 'lucide-react-native';

import { Screen } from '../../src/components/ui/Screen';
import { Input } from '../../src/components/ui/Input';
import { Button } from '../../src/components/ui/Button';
import { useColors } from '../../src/hooks/useColors';
import { font, fontSize, radius, spacing } from '../../src/lib/theme';
import { resetPassword, authErrorMessage } from '../../src/lib/firebase';

export default function Recovery() {
  const { colors } = useColors();
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [loading, setLoading] = useState(false);
  const [msg, setMsg] = useState<{ type: 'ok' | 'err'; text: string } | null>(null);

  const handle = async () => {
    setLoading(true);
    setMsg(null);
    try {
      await resetPassword(email);
      setMsg({ type: 'ok', text: 'Link de recuperação enviado para o seu e-mail.' });
    } catch (e) {
      setMsg({ type: 'err', text: authErrorMessage(e) });
    } finally {
      setLoading(false);
    }
  };

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
      <Text style={{ color: colors.textMuted, fontWeight: font.medium, marginBottom: spacing.sm }}>
        Informe seu e-mail para receber um link de redefinição de senha.
      </Text>

      {msg ? (
        <View
          style={{
            backgroundColor: msg.type === 'ok' ? colors.primarySoft : colors.dangerSoft,
            borderRadius: radius.md,
            padding: spacing.md,
            borderWidth: 2,
            borderColor: msg.type === 'ok' ? colors.primary : colors.danger,
          }}
        >
          <Text
            style={{
              color: msg.type === 'ok' ? colors.primaryDark : colors.danger,
              fontWeight: font.semibold,
              textAlign: 'center',
            }}
          >
            {msg.text}
          </Text>
        </View>
      ) : null}

      <Input
        placeholder="Seu e-mail"
        keyboardType="email-address"
        autoCapitalize="none"
        autoCorrect={false}
        value={email}
        onChangeText={setEmail}
        icon={<Mail size={20} color={colors.textSubtle} />}
      />
      <View style={{ height: spacing.sm }} />
      <Button label="Enviar link" size="lg" loading={loading} onPress={handle} />
    </Screen>
  );
}
