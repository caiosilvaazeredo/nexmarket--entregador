import React, { useState } from 'react';
import { View, Text } from 'react-native';
import { useRouter } from 'expo-router';
import { ArrowLeft, Mail, Lock } from 'lucide-react-native';

import { Screen } from '../../src/components/ui/Screen';
import { Input } from '../../src/components/ui/Input';
import { Button } from '../../src/components/ui/Button';
import { useColors } from '../../src/hooks/useColors';
import { font, fontSize, radius, spacing } from '../../src/lib/theme';
import { registerWithEmail, authErrorMessage } from '../../src/lib/firebase';

export default function Register() {
  const { colors } = useColors();
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleRegister = async () => {
    setError(null);
    if (password.length < 6) return setError('A senha deve ter ao menos 6 caracteres.');
    if (password !== confirm) return setError('As senhas não coincidem.');
    setLoading(true);
    try {
      await registerWithEmail(email, password);
      // Gate routes to onboarding to complete the driver profile.
    } catch (e) {
      setError(authErrorMessage(e));
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
        Criar conta
      </Text>
      <Text style={{ color: colors.textMuted, fontWeight: font.medium, marginBottom: spacing.sm }}>
        Comece com seu e-mail. Em seguida você cadastra veículo e documentos.
      </Text>

      {error ? (
        <View
          style={{
            backgroundColor: colors.dangerSoft,
            borderRadius: radius.md,
            padding: spacing.md,
            borderWidth: 2,
            borderColor: colors.danger,
          }}
        >
          <Text style={{ color: colors.danger, fontWeight: font.semibold, textAlign: 'center' }}>
            {error}
          </Text>
        </View>
      ) : null}

      <Input
        placeholder="E-mail"
        keyboardType="email-address"
        autoCapitalize="none"
        autoCorrect={false}
        value={email}
        onChangeText={setEmail}
        icon={<Mail size={20} color={colors.textSubtle} />}
      />
      <Input
        placeholder="Senha (mín. 6 caracteres)"
        secureTextEntry
        value={password}
        onChangeText={setPassword}
        icon={<Lock size={20} color={colors.textSubtle} />}
      />
      <Input
        placeholder="Confirmar senha"
        secureTextEntry
        value={confirm}
        onChangeText={setConfirm}
        icon={<Lock size={20} color={colors.textSubtle} />}
      />

      <View style={{ height: spacing.sm }} />
      <Button label="Continuar" size="lg" loading={loading} onPress={handleRegister} />
    </Screen>
  );
}
