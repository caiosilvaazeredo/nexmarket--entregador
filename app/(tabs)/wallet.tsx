import React, { useState, useEffect, useMemo } from 'react';
import { View, Text, Modal, Alert } from 'react-native';
import { Wallet as WalletIcon, ArrowDownToLine, Banknote, Clock, CheckCircle2 } from 'lucide-react-native';

import { Screen } from '../../src/components/ui/Screen';
import { Card } from '../../src/components/ui/Card';
import { Button } from '../../src/components/ui/Button';
import { Input } from '../../src/components/ui/Input';
import { Badge } from '../../src/components/ui/Badge';
import { useColors } from '../../src/hooks/useColors';
import { font, fontSize, radius, spacing, palette } from '../../src/lib/theme';
import { brl, formatDateTime, toDate } from '../../src/lib/format';
import { useDriverStore } from '../../src/store/useDriverStore';
import { subscribePayouts, requestPayout } from '../../src/lib/payouts';
import type { Payout } from '../../src/lib/types';

function periodSum(orders: any[], since: number) {
  return orders
    .filter((o) => (o.deliveryStatus === 'delivered' || o.status === 'delivered'))
    .filter((o) => (toDate(o.deliveredAt)?.getTime() ?? 0) >= since)
    .reduce((acc, o) => acc + (o.driverEarnings || 0), 0);
}

export default function WalletScreen() {
  const { colors } = useColors();
  const driver = useDriverStore((s) => s.driver);
  const myDeliveries = useDriverStore((s) => s.myDeliveries);
  const [payouts, setPayouts] = useState<Payout[]>([]);
  const [showWithdraw, setShowWithdraw] = useState(false);
  const [amount, setAmount] = useState('');
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    if (!driver) return;
    const unsub = subscribePayouts(driver.uid, setPayouts);
    return unsub;
  }, [driver?.uid]);

  const sums = useMemo(() => {
    const now = new Date();
    const day = new Date(now);
    day.setHours(0, 0, 0, 0);
    const week = new Date(day);
    week.setDate(week.getDate() - ((day.getDay() + 6) % 7));
    const month = new Date(now.getFullYear(), now.getMonth(), 1);
    return {
      today: periodSum(myDeliveries, day.getTime()),
      week: periodSum(myDeliveries, week.getTime()),
      month: periodSum(myDeliveries, month.getTime()),
    };
  }, [myDeliveries]);

  const balance = driver?.balance || 0;

  const submitWithdraw = async () => {
    if (!driver) return;
    const value = Number(amount.replace(',', '.'));
    if (!value || value <= 0) return Alert.alert('Atenção', 'Informe um valor válido.');
    if (value > balance) return Alert.alert('Atenção', 'Valor maior que o saldo disponível.');
    const dest = driver.bank?.pixKey || driver.bank?.account;
    if (!dest)
      return Alert.alert(
        'Dados bancários',
        'Cadastre sua chave PIX ou conta no Perfil antes de sacar.',
      );
    setSubmitting(true);
    try {
      await requestPayout(driver.uid, value, driver.bank?.pixKey ? 'PIX' : 'Conta bancária', dest);
      setShowWithdraw(false);
      setAmount('');
      Alert.alert('Saque solicitado', 'Seu saque foi solicitado e será processado em breve.');
    } catch (e) {
      Alert.alert('Erro', 'Não foi possível solicitar o saque.');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <Screen title="Carteira" subtitle="Seus ganhos e saques">
      {/* Balance card */}
      <Card elevated style={{ backgroundColor: colors.primary, borderColor: colors.primaryDark }}>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
          <WalletIcon size={18} color="#FFFFFF" />
          <Text style={{ color: 'rgba(255,255,255,0.9)', fontWeight: font.bold }}>Saldo disponível</Text>
        </View>
        <Text style={{ color: '#FFFFFF', fontWeight: font.black, fontSize: 40, marginTop: 4 }}>
          {brl(balance)}
        </Text>
        <Button
          label="Solicitar saque"
          variant="secondary"
          style={{ marginTop: spacing.md }}
          icon={<ArrowDownToLine size={18} color={colors.text} />}
          onPress={() => setShowWithdraw(true)}
        />
      </Card>

      {/* Earnings breakdown */}
      <Card>
        <Text style={{ color: colors.text, fontWeight: font.black, fontSize: fontSize.lg, marginBottom: spacing.md }}>
          Relatório de ganhos
        </Text>
        <Row colors={colors} label="Hoje" value={brl(sums.today)} />
        <Row colors={colors} label="Esta semana" value={brl(sums.week)} />
        <Row colors={colors} label="Este mês" value={brl(sums.month)} last />
      </Card>

      {/* Payout history */}
      <Text style={{ color: colors.text, fontWeight: font.black, fontSize: fontSize.lg }}>Saques</Text>
      {payouts.length === 0 ? (
        <Card>
          <View style={{ alignItems: 'center', paddingVertical: spacing.md }}>
            <Banknote size={32} color={colors.textSubtle} />
            <Text style={{ color: colors.textMuted, fontWeight: font.medium, marginTop: 6 }}>
              Nenhum saque solicitado.
            </Text>
          </View>
        </Card>
      ) : (
        payouts.map((p) => {
          const paid = p.status === 'paid';
          return (
            <Card key={p.id}>
              <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' }}>
                <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}>
                  {paid ? (
                    <CheckCircle2 size={22} color={colors.primary} />
                  ) : (
                    <Clock size={22} color={colors.amber} />
                  )}
                  <View>
                    <Text style={{ color: colors.text, fontWeight: font.black, fontSize: fontSize.lg }}>
                      {brl(p.amount)}
                    </Text>
                    <Text style={{ color: colors.textMuted, fontWeight: font.medium, fontSize: fontSize.xs }}>
                      {p.method} • {formatDateTime(p.createdAt)}
                    </Text>
                  </View>
                </View>
                <Badge
                  label={
                    p.status === 'paid'
                      ? 'Pago'
                      : p.status === 'processing'
                      ? 'Processando'
                      : p.status === 'rejected'
                      ? 'Recusado'
                      : 'Solicitado'
                  }
                  fg={paid ? '#166534' : colors.text}
                  bg={paid ? palette.greenSoft : colors.cardMuted}
                />
              </View>
            </Card>
          );
        })
      )}

      <View style={{ height: 8 }} />

      <Modal visible={showWithdraw} transparent animationType="slide" onRequestClose={() => setShowWithdraw(false)}>
        <View style={{ flex: 1, backgroundColor: colors.overlay, justifyContent: 'flex-end' }}>
          <View
            style={{
              backgroundColor: colors.card,
              borderTopLeftRadius: radius['2xl'],
              borderTopRightRadius: radius['2xl'],
              padding: spacing.xl,
              gap: spacing.md,
            }}
          >
            <Text style={{ color: colors.text, fontWeight: font.black, fontSize: fontSize.xl }}>Solicitar saque</Text>
            <Text style={{ color: colors.textMuted, fontWeight: font.medium }}>
              Saldo disponível: {brl(balance)}
            </Text>
            <Input
              label="Valor (R$)"
              keyboardType="decimal-pad"
              placeholder="0,00"
              value={amount}
              onChangeText={setAmount}
            />
            <Text style={{ color: colors.textSubtle, fontWeight: font.medium, fontSize: fontSize.sm }}>
              Destino: {driver?.bank?.pixKey ? `PIX ${driver.bank.pixKey}` : driver?.bank?.account || 'cadastre no Perfil'}
            </Text>
            <Button label="Confirmar saque" size="lg" loading={submitting} onPress={submitWithdraw} />
            <Button label="Cancelar" variant="ghost" onPress={() => setShowWithdraw(false)} />
          </View>
        </View>
      </Modal>
    </Screen>
  );
}

function Row({ colors, label, value, last }: { colors: any; label: string; value: string; last?: boolean }) {
  return (
    <View
      style={{
        flexDirection: 'row',
        justifyContent: 'space-between',
        alignItems: 'center',
        paddingVertical: spacing.sm,
        borderBottomWidth: last ? 0 : 1,
        borderBottomColor: colors.border,
      }}
    >
      <Text style={{ color: colors.textMuted, fontWeight: font.semibold }}>{label}</Text>
      <Text style={{ color: colors.text, fontWeight: font.black, fontSize: fontSize.lg }}>{value}</Text>
    </View>
  );
}
