import React, { useState, useEffect, useMemo } from 'react';
import { View, Text, Modal, Alert } from 'react-native';
import { Wallet as WalletIcon, ArrowDownToLine, Banknote, Clock, CheckCircle2, CreditCard } from 'lucide-react-native';

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
import { reconcilePendingTips } from '../../src/lib/orders';
import { paymentsConfigured, getRecipientStatus, registerRecipient, type RecipientStatus } from '../../src/lib/payments';
import type { Payout } from '../../src/lib/types';

function periodSum(orders: any[], since: number) {
  return orders
    .filter((o) => (o.deliveryStatus === 'delivered' || o.status === 'delivered'))
    .filter((o) => (toDate(o.deliveredAt)?.getTime() ?? 0) >= since)
    .reduce((acc, o) => acc + (o.driverEarnings || 0) + (o.tip || 0), 0);
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

  // Gorjetas pós-entrega ainda não creditadas → entram no saldo aqui.
  useEffect(() => {
    if (!driver || !myDeliveries.length) return;
    reconcilePendingTips(driver.uid, myDeliveries).then((credited) => {
      if (credited > 0) {
        Alert.alert('Gorjeta recebida! 💚', `${brl(credited)} de gorjeta foram adicionados ao seu saldo.`);
      }
    });
  }, [driver?.uid, myDeliveries]);

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

      {/* Recebedor Pagar.me — conta que recebe os repasses aprovados pela plataforma */}
      {paymentsConfigured() ? <RecebedorCard /> : null}

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
                      {p.transferId ? 'Pagar.me' : p.method} • {formatDateTime(p.createdAt)}
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

/**
 * Cadastro de recebedor Pagar.me: quando concluído e aprovado, os saques
 * aprovados pela plataforma caem direto na conta bancária do entregador
 * (POST /api/payouts/transfer, disparado pelo painel Empresa).
 */
function RecebedorCard() {
  const { colors } = useColors();
  const driver = useDriverStore((s) => s.driver);
  const [status, setStatus] = useState<RecipientStatus | null>(null);
  const [showForm, setShowForm] = useState(false);
  const [busy, setBusy] = useState(false);

  const [document, setDocumentCpf] = useState(driver?.bank?.cpf || '');
  const [birthdate, setBirthdate] = useState('');
  const [bankCode, setBankCode] = useState('');
  const [branch, setBranch] = useState(driver?.bank?.agency || '');
  const [branchDigit, setBranchDigit] = useState('');
  const [account, setAccount] = useState(driver?.bank?.account || '');
  const [accountDigit, setAccountDigit] = useState('');

  const refresh = async () => {
    try {
      setStatus(await getRecipientStatus());
    } catch {
      setStatus(null);
    }
  };

  useEffect(() => {
    refresh();
  }, []);

  const submit = async () => {
    if (!driver) return;
    const cpfDigits = document.replace(/\D/g, '');
    if (cpfDigits.length !== 11) return Alert.alert('CPF', 'Informe um CPF válido (11 dígitos).');
    if (!birthdate || !/^\d{4}-\d{2}-\d{2}$/.test(birthdate)) return Alert.alert('Nascimento', 'Informe a data no formato AAAA-MM-DD.');
    if (!bankCode || !branch || !account || !accountDigit) return Alert.alert('Dados bancários', 'Preencha banco, agência, conta e dígito da conta.');

    setBusy(true);
    try {
      await registerRecipient({
        document: cpfDigits,
        name: driver.name,
        email: driver.email,
        birthdate,
        occupation: 'Entregador',
        bank: {
          holderName: driver.name,
          holderDocument: cpfDigits,
          bank: bankCode,
          branchNumber: branch,
          branchCheckDigit: branchDigit || undefined,
          accountNumber: account,
          accountCheckDigit: accountDigit,
          accountType: 'checking',
        },
      });
      setShowForm(false);
      await refresh();
      Alert.alert('Cadastro enviado', 'Seu cadastro de recebedor foi enviado para análise.');
    } catch (e: any) {
      Alert.alert('Recebimento Pagar.me', e?.message || 'Não foi possível enviar o cadastro agora.');
    } finally {
      setBusy(false);
    }
  };

  const ready = status?.status === 'active';

  return (
    <Card>
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
        <CreditCard size={18} color={colors.primary} />
        <Text style={{ color: colors.text, fontWeight: font.black, fontSize: fontSize.lg, flex: 1 }}>
          Recebimento automático
        </Text>
        <Badge
          label={ready ? 'Ativo' : status?.configured ? 'Em análise' : 'Não configurado'}
          fg={ready ? '#166534' : colors.text}
          bg={ready ? palette.greenSoft : colors.cardMuted}
        />
      </View>
      <Text style={{ color: colors.textMuted, fontWeight: font.medium, fontSize: fontSize.sm, marginTop: 6 }}>
        {ready
          ? 'Seu cadastro está pronto: os saques aprovados caem direto na sua conta bancária.'
          : 'Cadastre seus dados na Pagar.me para receber os repasses automaticamente.'}
      </Text>
      {!ready ? (
        <Button
          label={status?.configured ? 'Ver cadastro' : 'Configurar recebimento'}
          variant="secondary"
          style={{ marginTop: spacing.md }}
          onPress={() => setShowForm(true)}
        />
      ) : null}

      <Modal visible={showForm} transparent animationType="slide" onRequestClose={() => setShowForm(false)}>
        <View style={{ flex: 1, backgroundColor: colors.overlay, justifyContent: 'flex-end' }}>
          <View style={{ backgroundColor: colors.card, borderTopLeftRadius: radius['2xl'], borderTopRightRadius: radius['2xl'], padding: spacing.xl, gap: spacing.md, maxHeight: '85%' }}>
            <Text style={{ color: colors.text, fontWeight: font.black, fontSize: fontSize.xl }}>Cadastro de recebedor</Text>
            <Text style={{ color: colors.textMuted, fontSize: fontSize.sm }}>
              Esses dados vão direto para a Pagar.me (processadora de pagamentos) — nunca ficam salvos aqui além do necessário.
            </Text>
            <Input label="CPF" keyboardType="number-pad" placeholder="000.000.000-00" value={document} onChangeText={setDocumentCpf} />
            <Input label="Data de nascimento (AAAA-MM-DD)" placeholder="1990-05-20" value={birthdate} onChangeText={setBirthdate} />
            <View style={{ flexDirection: 'row', gap: spacing.md }}>
              <Input containerStyle={{ flex: 1 }} label="Código do banco" placeholder="Ex: 260" keyboardType="number-pad" value={bankCode} onChangeText={setBankCode} />
              <Input containerStyle={{ flex: 1 }} label="Agência" keyboardType="number-pad" value={branch} onChangeText={setBranch} />
              <Input containerStyle={{ width: 80 }} label="Díg." keyboardType="number-pad" value={branchDigit} onChangeText={setBranchDigit} />
            </View>
            <View style={{ flexDirection: 'row', gap: spacing.md }}>
              <Input containerStyle={{ flex: 1 }} label="Conta" keyboardType="number-pad" value={account} onChangeText={setAccount} />
              <Input containerStyle={{ width: 80 }} label="Díg." keyboardType="number-pad" value={accountDigit} onChangeText={setAccountDigit} />
            </View>
            <Button label="Enviar cadastro" size="lg" loading={busy} onPress={submit} />
            <Button label="Cancelar" variant="ghost" onPress={() => setShowForm(false)} />
          </View>
        </View>
      </Modal>
    </Card>
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
