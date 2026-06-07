import React, { useState } from 'react';
import { View, Text, ScrollView, Pressable, Modal, Image, Alert, Linking } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useLocalSearchParams, useRouter } from 'expo-router';
import {
  ArrowLeft,
  Store,
  MapPin,
  Navigation,
  Phone,
  MessageCircle,
  Camera,
  Check,
  CircleAlert,
  PackageCheck,
  ShoppingBag,
  X,
  CheckCircle2,
} from 'lucide-react-native';

import { Card } from '../../src/components/ui/Card';
import { Button } from '../../src/components/ui/Button';
import { Input } from '../../src/components/ui/Input';
import { MapPanel, MapMarker } from '../../src/components/MapPanel';
import { SignaturePad } from '../../src/components/SignaturePad';
import { useColors } from '../../src/hooks/useColors';
import { font, fontSize, radius, spacing, shadow, palette } from '../../src/lib/theme';
import { brl, fullAddress } from '../../src/lib/format';
import { isValidGeo, openNavigation, openNavigationQuery, regionFor } from '../../src/lib/geo';
import { useDriverStore } from '../../src/store/useDriverStore';
import {
  arrivedAtStore,
  confirmPickup,
  completeDelivery,
  reportProblem,
  estimateEarnings,
} from '../../src/lib/orders';
import { pickImage } from '../../src/lib/images';
import type { Order, ProblemType } from '../../src/lib/types';

const PROBLEMS: { type: ProblemType; label: string }[] = [
  { type: 'address_not_found', label: 'Endereço não encontrado' },
  { type: 'customer_absent', label: 'Cliente ausente' },
  { type: 'damaged_package', label: 'Pacote danificado' },
  { type: 'other', label: 'Outro problema' },
];

export default function DeliveryFlow() {
  const { colors } = useColors();
  const router = useRouter();
  const params = useLocalSearchParams<{ id: string; sm?: string }>();
  const driver = useDriverStore((s) => s.driver);
  const order = useDriverStore((s) => s.myDeliveries.find((o) => o.id === params.id)) as Order | undefined;

  const [busy, setBusy] = useState(false);
  const [showPOD, setShowPOD] = useState(false);
  const [showProblem, setShowProblem] = useState(false);
  const [showItems, setShowItems] = useState(false);

  // POD state
  const [signature, setSignature] = useState('');
  const [podPhoto, setPodPhoto] = useState<string | null>(null);
  const [receivedBy, setReceivedBy] = useState('');
  const [note, setNote] = useState('');

  // Problem state
  const [problemNote, setProblemNote] = useState('');

  const navApp = driver?.preferences?.navApp || 'google';

  if (!order) {
    return (
      <SafeAreaView style={{ flex: 1, backgroundColor: colors.bg, alignItems: 'center', justifyContent: 'center', gap: 16 }}>
        <PackageCheck size={48} color={colors.textSubtle} />
        <Text style={{ color: colors.textMuted, fontWeight: font.bold }}>Carregando entrega…</Text>
        <Button label="Voltar" variant="ghost" fullWidth={false} onPress={() => router.replace('/(tabs)')} />
      </SafeAreaView>
    );
  }

  const status = order.deliveryStatus;
  const atStorePhase = status === 'going_to_store' || status === 'arrived_store';
  const finished = status === 'delivered' || order.status === 'delivered';

  const navStore = () => {
    if (isValidGeo(order.storeLocation))
      openNavigation({ lat: order.storeLocation!.lat, lng: order.storeLocation!.lng }, navApp, order.storeName);
    else openNavigationQuery(order.storeAddress || order.storeName || 'mercado', navApp);
  };
  const navCustomer = () => {
    const a = order.deliveryAddress;
    if (a && typeof a.lat === 'number' && typeof a.lng === 'number')
      openNavigation({ lat: a.lat, lng: a.lng }, navApp, order.customerName);
    else openNavigationQuery(fullAddress(a), navApp);
  };

  const run = async (fn: () => Promise<boolean>, queuedMsg = 'Ação salva. Sincronizando ao reconectar.') => {
    setBusy(true);
    try {
      const applied = await fn();
      if (!applied) Alert.alert('Salvo offline', queuedMsg);
    } catch (e) {
      Alert.alert('Erro', 'Não foi possível concluir a ação. Tente novamente.');
    } finally {
      setBusy(false);
    }
  };

  const onArrived = () => run(() => arrivedAtStore(order));
  const onPickup = () => run(() => confirmPickup(order));

  const onReportProblem = async (type: ProblemType) => {
    setShowProblem(false);
    await run(() => reportProblem(order, type, problemNote));
    setProblemNote('');
  };

  const onConfirmPOD = async () => {
    if (!signature && !podPhoto) {
      return Alert.alert('Comprovante', 'Capture a assinatura do cliente ou uma foto da entrega.');
    }
    setBusy(true);
    try {
      const applied = await completeDelivery(order, {
        signatureUrl: signature,
        photoUrl: podPhoto || '',
        note,
        receivedBy,
      });
      setShowPOD(false);
      Alert.alert(
        'Entrega concluída! 🎉',
        applied
          ? `Você ganhou ${brl(order.driverEarnings || estimateEarnings(order))}.`
          : 'Comprovante salvo. Será sincronizado assim que houver conexão.',
      );
      router.replace('/(tabs)');
    } catch (e) {
      Alert.alert('Erro', 'Não foi possível finalizar a entrega.');
    } finally {
      setBusy(false);
    }
  };

  const takePodPhoto = async () => {
    const uri = await pickImage({ camera: true, maxWidth: 1000, quality: 0.5 });
    if (uri) setPodPhoto(uri);
  };

  // Map markers
  const markers: MapMarker[] = [];
  if (isValidGeo(order.storeLocation))
    markers.push({ id: 'store', lat: order.storeLocation!.lat, lng: order.storeLocation!.lng, title: order.storeName, color: colors.accent });
  if (order.deliveryAddress?.lat && order.deliveryAddress?.lng)
    markers.push({ id: 'cust', lat: order.deliveryAddress.lat, lng: order.deliveryAddress.lng, title: order.customerName, color: colors.danger });
  const focus = atStorePhase ? order.storeLocation : (order.deliveryAddress?.lat ? { lat: order.deliveryAddress.lat, lng: order.deliveryAddress.lng } : order.storeLocation);
  const region = focus && isValidGeo(focus as any) ? regionFor({ lat: (focus as any).lat, lng: (focus as any).lng }) : undefined;

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: colors.bg }} edges={['top', 'bottom']}>
      {/* Header */}
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, paddingHorizontal: spacing.md, paddingVertical: spacing.sm }}>
        <Pressable onPress={() => router.replace('/(tabs)')} hitSlop={10} style={{ padding: 6 }}>
          <ArrowLeft size={24} color={colors.text} />
        </Pressable>
        <View style={{ flex: 1 }}>
          <Text style={{ color: colors.textMuted, fontWeight: font.bold, fontSize: fontSize.xs }}>
            ENTREGA #{order.id.slice(0, 6).toUpperCase()}
          </Text>
          <Text style={{ color: colors.text, fontWeight: font.black, fontSize: fontSize.xl }}>
            {atStorePhase ? 'Coleta na loja' : finished ? 'Entrega concluída' : 'Entrega ao cliente'}
          </Text>
        </View>
      </View>

      <ScrollView contentContainerStyle={{ padding: spacing.lg, gap: spacing.md, paddingBottom: 24 }} showsVerticalScrollIndicator={false}>
        <MapPanel region={region} markers={markers} height={200} />

        {/* Step tracker */}
        <StepTracker status={status} colors={colors} />

        {/* Destination card */}
        {finished ? (
          <Card elevated style={{ borderColor: colors.primary }}>
            <View style={{ alignItems: 'center', gap: 8, paddingVertical: spacing.md }}>
              <CheckCircle2 size={48} color={colors.primary} />
              <Text style={{ color: colors.text, fontWeight: font.black, fontSize: fontSize.xl }}>Entrega finalizada</Text>
              <Text style={{ color: colors.primaryDark, fontWeight: font.black, fontSize: fontSize['2xl'] }}>
                {brl(order.driverEarnings || 0)}
              </Text>
            </View>
          </Card>
        ) : (
          <Card>
            <View style={{ flexDirection: 'row', alignItems: 'flex-start', gap: 12 }}>
              <View style={{ width: 44, height: 44, borderRadius: radius.md, backgroundColor: atStorePhase ? colors.accentSoft : colors.dangerSoft, alignItems: 'center', justifyContent: 'center' }}>
                {atStorePhase ? <Store size={22} color={colors.accent} /> : <MapPin size={22} color={colors.danger} />}
              </View>
              <View style={{ flex: 1 }}>
                <Text style={{ color: colors.textMuted, fontWeight: font.bold, fontSize: fontSize.xs }}>
                  {atStorePhase ? 'RETIRAR EM' : 'ENTREGAR EM'}
                </Text>
                <Text style={{ color: colors.text, fontWeight: font.black, fontSize: fontSize.lg }}>
                  {atStorePhase ? order.storeName || 'Loja' : order.customerName || 'Cliente'}
                </Text>
                <Text style={{ color: colors.textMuted, fontWeight: font.medium }}>
                  {atStorePhase ? order.storeAddress || 'Veja a rota no mapa' : fullAddress(order.deliveryAddress)}
                </Text>
              </View>
            </View>
            <Button
              label={atStorePhase ? 'Navegar até a loja' : 'Navegar até o cliente'}
              variant="secondary"
              icon={<Navigation size={18} color={colors.accent} />}
              style={{ marginTop: spacing.md }}
              onPress={atStorePhase ? navStore : navCustomer}
            />
          </Card>
        )}

        {/* Communication (customer phase) */}
        {!atStorePhase && !finished ? (
          <View style={{ flexDirection: 'row', gap: spacing.md }}>
            <Button
              label="Ligar"
              variant="secondary"
              icon={<Phone size={18} color={colors.text} />}
              style={{ flex: 1 }}
              onPress={() =>
                order.customerPhone
                  ? Linking.openURL(`tel:${order.customerPhone}`)
                  : Alert.alert('Contato', 'Telefone do cliente não informado.')
              }
            />
            <Button
              label="Mensagem"
              variant="secondary"
              icon={<MessageCircle size={18} color={colors.text} />}
              style={{ flex: 1 }}
              onPress={() => router.push(`/chat/${order.id}?sm=${order.supermarketId}`)}
            />
          </View>
        ) : null}

        {/* Items */}
        <Card>
          <Pressable onPress={() => setShowItems((s) => !s)} style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' }}>
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
              <ShoppingBag size={18} color={colors.text} />
              <Text style={{ color: colors.text, fontWeight: font.black, fontSize: fontSize.base }}>
                {order.items?.length || 0} itens • {brl(order.total)}
              </Text>
            </View>
            <Text style={{ color: colors.primary, fontWeight: font.bold }}>{showItems ? 'ocultar' : 'ver'}</Text>
          </Pressable>
          {showItems ? (
            <View style={{ marginTop: spacing.md, gap: spacing.sm }}>
              {order.items?.map((it, i) => (
                <View key={i} style={{ flexDirection: 'row', justifyContent: 'space-between', paddingVertical: 4, borderBottomWidth: i < order.items.length - 1 ? 1 : 0, borderBottomColor: colors.border }}>
                  <Text style={{ color: colors.text, fontWeight: font.medium, flex: 1 }}>
                    {it.quantity}x {it.name}
                  </Text>
                  <Text style={{ color: colors.textMuted, fontWeight: font.semibold }}>{brl(it.price * it.quantity)}</Text>
                </View>
              ))}
            </View>
          ) : null}
        </Card>

        {/* Report problem */}
        {!finished ? (
          <Button
            label="Reportar um problema"
            variant="ghost"
            icon={<CircleAlert size={18} color={colors.danger} />}
            textStyle={{ color: colors.danger }}
            onPress={() => setShowProblem(true)}
          />
        ) : null}
      </ScrollView>

      {/* Bottom primary action */}
      {!finished ? (
        <View style={[{ padding: spacing.lg, paddingTop: spacing.md, backgroundColor: colors.card, borderTopWidth: 2, borderTopColor: colors.border }, shadow.raised]}>
          {status === 'going_to_store' ? (
            <Button label="Cheguei na loja" size="lg" loading={busy} icon={<Store size={20} color="#fff" />} onPress={onArrived} />
          ) : status === 'arrived_store' ? (
            <Button label="Coletei os pacotes" size="lg" loading={busy} icon={<PackageCheck size={20} color="#fff" />} onPress={onPickup} />
          ) : status === 'problem' ? (
            <Button label="Retomar entrega" size="lg" loading={busy} onPress={() => run(() => confirmPickup(order))} />
          ) : (
            <Button label="Finalizar entrega" size="lg" loading={busy} icon={<Check size={20} color="#fff" />} onPress={() => setShowPOD(true)} />
          )}
        </View>
      ) : (
        <View style={{ padding: spacing.lg }}>
          <Button label="Voltar ao início" size="lg" onPress={() => router.replace('/(tabs)')} />
        </View>
      )}

      {/* POD modal */}
      <Modal visible={showPOD} transparent animationType="slide" onRequestClose={() => setShowPOD(false)}>
        <View style={{ flex: 1, backgroundColor: colors.overlay, justifyContent: 'flex-end' }}>
          <View style={{ backgroundColor: colors.card, borderTopLeftRadius: radius['2xl'], borderTopRightRadius: radius['2xl'], maxHeight: '92%' }}>
            <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', padding: spacing.lg, borderBottomWidth: 1, borderBottomColor: colors.border }}>
              <Text style={{ color: colors.text, fontWeight: font.black, fontSize: fontSize.xl }}>Comprovante de entrega</Text>
              <Pressable onPress={() => setShowPOD(false)} hitSlop={10}>
                <X size={24} color={colors.textMuted} />
              </Pressable>
            </View>
            <ScrollView contentContainerStyle={{ padding: spacing.lg, gap: spacing.md }} keyboardShouldPersistTaps="handled">
              <Text style={{ color: colors.textMuted, fontWeight: font.bold, fontSize: fontSize.xs }}>ASSINATURA DO CLIENTE</Text>
              <SignaturePad onChange={setSignature} />

              <Text style={{ color: colors.textMuted, fontWeight: font.bold, fontSize: fontSize.xs, marginTop: spacing.sm }}>FOTO DA ENTREGA</Text>
              {podPhoto ? (
                <View>
                  <Image source={{ uri: podPhoto }} style={{ width: '100%', height: 180, borderRadius: radius.lg }} />
                  <Button label="Refazer foto" variant="ghost" size="sm" onPress={takePodPhoto} />
                </View>
              ) : (
                <Button label="Tirar foto do pacote" variant="secondary" icon={<Camera size={18} color={colors.text} />} onPress={takePodPhoto} />
              )}

              <Input label="Recebido por (opcional)" placeholder="Nome de quem recebeu" value={receivedBy} onChangeText={setReceivedBy} />
              <Input label="Observação (opcional)" placeholder="Ex: deixado na portaria" value={note} onChangeText={setNote} />

              <Button label="Confirmar entrega" size="lg" loading={busy} onPress={onConfirmPOD} />
              <View style={{ height: spacing.lg }} />
            </ScrollView>
          </View>
        </View>
      </Modal>

      {/* Problem modal */}
      <Modal visible={showProblem} transparent animationType="slide" onRequestClose={() => setShowProblem(false)}>
        <View style={{ flex: 1, backgroundColor: colors.overlay, justifyContent: 'flex-end' }}>
          <View style={{ backgroundColor: colors.card, borderTopLeftRadius: radius['2xl'], borderTopRightRadius: radius['2xl'], padding: spacing.lg, gap: spacing.sm }}>
            <Text style={{ color: colors.text, fontWeight: font.black, fontSize: fontSize.xl }}>Reportar problema</Text>
            <Input placeholder="Detalhe o que aconteceu (opcional)" value={problemNote} onChangeText={setProblemNote} />
            {PROBLEMS.map((p) => (
              <Pressable
                key={p.type}
                onPress={() => onReportProblem(p.type)}
                style={{ padding: spacing.md, borderRadius: radius.md, borderWidth: 2, borderColor: colors.border, backgroundColor: colors.cardMuted }}
              >
                <Text style={{ color: colors.text, fontWeight: font.bold }}>{p.label}</Text>
              </Pressable>
            ))}
            <Button label="Cancelar" variant="ghost" onPress={() => setShowProblem(false)} />
          </View>
        </View>
      </Modal>
    </SafeAreaView>
  );
}

const STEPS = [
  { key: 'going_to_store', label: 'A caminho' },
  { key: 'arrived_store', label: 'Na loja' },
  { key: 'going_to_customer', label: 'Coletado' },
  { key: 'delivered', label: 'Entregue' },
];

function StepTracker({ status, colors }: { status?: string; colors: any }) {
  const order = ['going_to_store', 'arrived_store', 'going_to_customer', 'delivered'];
  const currentIndex = status ? Math.max(0, order.indexOf(status === 'problem' ? 'going_to_customer' : status)) : 0;
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: 4 }}>
      {STEPS.map((s, i) => {
        const done = i <= currentIndex;
        return (
          <React.Fragment key={s.key}>
            <View style={{ alignItems: 'center', gap: 4, flex: 0 }}>
              <View
                style={{
                  width: 28,
                  height: 28,
                  borderRadius: 14,
                  backgroundColor: done ? colors.primary : colors.cardMuted,
                  borderWidth: 2,
                  borderColor: done ? colors.primary : colors.border,
                  alignItems: 'center',
                  justifyContent: 'center',
                }}
              >
                {done ? <Check size={16} color="#fff" /> : <Text style={{ color: colors.textSubtle, fontWeight: font.bold, fontSize: 12 }}>{i + 1}</Text>}
              </View>
              <Text style={{ color: done ? colors.text : colors.textSubtle, fontWeight: font.semibold, fontSize: 10 }}>{s.label}</Text>
            </View>
            {i < STEPS.length - 1 ? (
              <View style={{ flex: 1, height: 2, backgroundColor: i < currentIndex ? colors.primary : colors.border, marginHorizontal: 4, marginBottom: 14 }} />
            ) : null}
          </React.Fragment>
        );
      })}
    </View>
  );
}
