import React, { useState } from 'react';
import { View, Text, Alert } from 'react-native';
import { useRouter } from 'expo-router';
import { Truck, Mail, Lock } from 'lucide-react-native';

import { Screen } from '../../src/components/ui/Screen';
import { Input } from '../../src/components/ui/Input';
import { Button } from '../../src/components/ui/Button';
import { useColors } from '../../src/hooks/useColors';
import { font, fontSize, radius, spacing, shadow } from '../../src/lib/theme';
import { loginWithEmail, loginAsVisitor, authErrorMessage } from '../../src/lib/firebase';
import { createDriverProfile, getDriver } from '../../src/lib/drivers';

export default function Login() {
  const { colors } = useColors();
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleLogin = async () => {
    setLoading(true);
    setError(null);
    try {
      await loginWithEmail(email, password);
      // Navigation gate routes onward.
    } catch (e) {
      setError(authErrorMessage(e));
    } finally {
      setLoading(false);
    }
  };

  const handleVisitor = async () => {
    setLoading(true);
    setError(null);
    try {
      const u = await loginAsVisitor();
      const existing = await getDriver(u.uid);
      if (!existing) {
        // Seed a ready-to-use demo profile so testers skip onboarding.
        await createDriverProfile(u.uid, {
          name: 'Entregador Teste',
          email: '',
          phone: '',
          vehicle: { type: 'moto', plate: 'TEST-0000', model: 'Demo' },
        });
      }
      Alert.alert(
        'Modo teste',
        'Nada será cobrado. É apenas uma demonstração do app do entregador.',
      );
    } catch (e) {
      setError(authErrorMessage(e));
    } finally {
      setLoading(false);
    }
  };

  return (
    <Screen contentStyle={{ flexGrow: 1, justifyContent: 'center', gap: spacing.lg }}>
      <View style={{ alignItems: 'center', gap: spacing.md, marginBottom: spacing.lg }}>
        <View
          style={[
            {
              width: 80,
              height: 80,
              borderRadius: radius['2xl'],
              backgroundColor: colors.primary,
              alignItems: 'center',
              justifyContent: 'center',
              transform: [{ rotate: '12deg' }],
            },
            shadow.card,
          ]}
        >
          <Truck color="#FFFFFF" size={40} strokeWidth={3} style={{ transform: [{ rotate: '-12deg' }] }} />
        </View>
        <Text style={{ color: colors.text, fontWeight: font.black, fontSize: fontSize['3xl'] }}>
          Nexmarket
        </Text>
        <Text style={{ color: colors.textMuted, fontWeight: font.medium }}>
          Central do Entregador
        </Text>
      </View>

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
        placeholder="Seu e-mail"
        keyboardType="email-address"
        autoCapitalize="none"
        autoCorrect={false}
        value={email}
        onChangeText={setEmail}
        icon={<Mail size={20} color={colors.textSubtle} />}
      />
      <Input
        placeholder="Sua senha"
        secureTextEntry
        value={password}
        onChangeText={setPassword}
        icon={<Lock size={20} color={colors.textSubtle} />}
      />

      <Button
        label="Esqueceu a senha?"
        variant="ghost"
        size="sm"
        fullWidth={false}
        style={{ alignSelf: 'flex-end' }}
        textStyle={{ color: colors.primary }}
        onPress={() => router.push('/(auth)/recovery')}
      />

      <Button label="Entrar" size="lg" loading={loading} onPress={handleLogin} />

      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12, marginVertical: spacing.xs }}>
        <View style={{ flex: 1, height: 1, backgroundColor: colors.border }} />
        <Text style={{ color: colors.textSubtle, fontWeight: font.medium }}>ou</Text>
        <View style={{ flex: 1, height: 1, backgroundColor: colors.border }} />
      </View>

      <Button label="Quero apenas testar" variant="secondary" loading={loading} onPress={handleVisitor} />

      <View style={{ flexDirection: 'row', justifyContent: 'center', alignItems: 'center', marginTop: spacing.sm }}>
        <Text style={{ color: colors.textMuted, fontWeight: font.medium }}>Não tem conta? </Text>
        <Button
          label="Cadastre-se"
          variant="ghost"
          size="sm"
          fullWidth={false}
          textStyle={{ color: colors.primary }}
          onPress={() => router.push('/(auth)/register')}
        />
      </View>
    </Screen>
  );
}
