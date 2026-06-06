import React, { useState } from 'react';
import { View, Text, Switch, Pressable, Image, Alert } from 'react-native';
import {
  User,
  Phone,
  Bike,
  Car,
  Truck,
  Banknote,
  Bell,
  Moon,
  Navigation,
  LogOut,
  Star,
  Save,
} from 'lucide-react-native';

import { Screen } from '../../src/components/ui/Screen';
import { Card } from '../../src/components/ui/Card';
import { Input } from '../../src/components/ui/Input';
import { Button } from '../../src/components/ui/Button';
import { useColors } from '../../src/hooks/useColors';
import { font, fontSize, radius, spacing } from '../../src/lib/theme';
import { useDriverStore } from '../../src/store/useDriverStore';
import {
  updateDriverProfile,
  updateVehicle,
  updateBank,
  updatePreferences,
  defaultPreferences,
} from '../../src/lib/drivers';
import { logout } from '../../src/lib/firebase';
import { pickImage } from '../../src/lib/images';
import type { VehicleType } from '../../src/lib/types';

const VEHICLES: { type: VehicleType; label: string; icon: any }[] = [
  { type: 'moto', label: 'Moto', icon: Bike },
  { type: 'carro', label: 'Carro', icon: Car },
  { type: 'bike', label: 'Bike', icon: Bike },
  { type: 'van', label: 'Van', icon: Truck },
];

export default function Profile() {
  const { colors } = useColors();
  const driver = useDriverStore((s) => s.driver);

  const [name, setName] = useState(driver?.name || '');
  const [phone, setPhone] = useState(driver?.phone || '');
  const [vtype, setVtype] = useState<VehicleType>(driver?.vehicle?.type || 'moto');
  const [plate, setPlate] = useState(driver?.vehicle?.plate || '');
  const [model, setModel] = useState(driver?.vehicle?.model || '');
  const [bank, setBank] = useState({
    holderName: driver?.bank?.holderName || '',
    cpf: driver?.bank?.cpf || '',
    bankName: driver?.bank?.bankName || '',
    agency: driver?.bank?.agency || '',
    account: driver?.bank?.account || '',
    pixKey: driver?.bank?.pixKey || '',
  });
  const prefs = driver?.preferences || defaultPreferences;
  const [savingKey, setSavingKey] = useState<string | null>(null);

  if (!driver) return <Screen title="Perfil"><View /></Screen>;

  const savePersonal = async () => {
    setSavingKey('personal');
    try {
      await updateDriverProfile(driver.uid, { name: name.trim(), phone: phone.trim() });
      Alert.alert('Pronto', 'Dados atualizados.');
    } finally {
      setSavingKey(null);
    }
  };
  const saveVehicle = async () => {
    setSavingKey('vehicle');
    try {
      await updateVehicle(driver.uid, { type: vtype, plate: plate.trim().toUpperCase(), model: model.trim() });
      Alert.alert('Pronto', 'Veículo atualizado.');
    } finally {
      setSavingKey(null);
    }
  };
  const saveBank = async () => {
    setSavingKey('bank');
    try {
      await updateBank(driver.uid, bank);
      Alert.alert('Pronto', 'Dados bancários atualizados.');
    } finally {
      setSavingKey(null);
    }
  };
  const setPref = async (patch: Partial<typeof prefs>) => {
    await updatePreferences(driver.uid, { ...prefs, ...patch });
  };
  const changePhoto = async () => {
    const uri = await pickImage({ camera: true, maxWidth: 600, quality: 0.5 });
    if (uri) await updateDriverProfile(driver.uid, { photoUrl: uri });
  };

  return (
    <Screen title="Perfil" subtitle="Conta e preferências">
      {/* Header */}
      <Card elevated>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.md }}>
          <Pressable onPress={changePhoto}>
            {driver.photoUrl ? (
              <Image source={{ uri: driver.photoUrl }} style={{ width: 64, height: 64, borderRadius: 32 }} />
            ) : (
              <View
                style={{
                  width: 64,
                  height: 64,
                  borderRadius: 32,
                  backgroundColor: colors.primarySoft,
                  alignItems: 'center',
                  justifyContent: 'center',
                }}
              >
                <Text style={{ color: colors.primaryDark, fontWeight: font.black, fontSize: fontSize['2xl'] }}>
                  {(driver.name || 'E')[0].toUpperCase()}
                </Text>
              </View>
            )}
          </Pressable>
          <View style={{ flex: 1 }}>
            <Text style={{ color: colors.text, fontWeight: font.black, fontSize: fontSize.xl }}>{driver.name}</Text>
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12, marginTop: 4 }}>
              <View style={{ flexDirection: 'row', alignItems: 'center', gap: 4 }}>
                <Star size={15} color={colors.amber} fill={colors.amber} />
                <Text style={{ color: colors.textMuted, fontWeight: font.bold }}>{(driver.rating || 5).toFixed(1)}</Text>
              </View>
              <Text style={{ color: colors.textMuted, fontWeight: font.medium, fontSize: fontSize.sm }}>
                {driver.totalDeliveries || 0} entregas
              </Text>
            </View>
          </View>
        </View>
      </Card>

      {/* Personal */}
      <Card>
        <SectionTitle colors={colors} icon={<User size={18} color={colors.primary} />} text="Dados pessoais" />
        <View style={{ gap: spacing.md }}>
          <Input placeholder="Nome completo" value={name} onChangeText={setName} icon={<User size={20} color={colors.textSubtle} />} />
          <Input placeholder="Telefone" keyboardType="phone-pad" value={phone} onChangeText={setPhone} icon={<Phone size={20} color={colors.textSubtle} />} />
          <Button label="Salvar" variant="secondary" loading={savingKey === 'personal'} icon={<Save size={18} color={colors.textMuted} />} onPress={savePersonal} />
        </View>
      </Card>

      {/* Vehicle */}
      <Card>
        <SectionTitle colors={colors} icon={<Bike size={18} color={colors.primary} />} text="Veículo" />
        <View style={{ flexDirection: 'row', gap: spacing.sm, marginBottom: spacing.md }}>
          {VEHICLES.map((v) => {
            const active = vtype === v.type;
            const Icon = v.icon;
            return (
              <Pressable
                key={v.type}
                onPress={() => setVtype(v.type)}
                style={{
                  flex: 1,
                  alignItems: 'center',
                  paddingVertical: 12,
                  borderRadius: radius.md,
                  borderWidth: 2,
                  borderColor: active ? colors.primary : colors.border,
                  backgroundColor: active ? colors.primarySoft : colors.cardMuted,
                }}
              >
                <Icon size={20} color={active ? colors.primaryDark : colors.textMuted} />
                <Text style={{ color: active ? colors.primaryDark : colors.textMuted, fontWeight: font.bold, fontSize: fontSize.xs, marginTop: 4 }}>
                  {v.label}
                </Text>
              </Pressable>
            );
          })}
        </View>
        <View style={{ gap: spacing.md }}>
          <Input placeholder="Placa" autoCapitalize="characters" value={plate} onChangeText={setPlate} />
          <Input placeholder="Modelo" value={model} onChangeText={setModel} />
          <Button label="Salvar" variant="secondary" loading={savingKey === 'vehicle'} icon={<Save size={18} color={colors.textMuted} />} onPress={saveVehicle} />
        </View>
      </Card>

      {/* Bank */}
      <Card>
        <SectionTitle colors={colors} icon={<Banknote size={18} color={colors.primary} />} text="Dados bancários" />
        <View style={{ gap: spacing.md }}>
          <Input placeholder="Chave PIX" value={bank.pixKey} onChangeText={(v) => setBank({ ...bank, pixKey: v })} />
          <Input placeholder="Titular da conta" value={bank.holderName} onChangeText={(v) => setBank({ ...bank, holderName: v })} />
          <Input placeholder="CPF" keyboardType="number-pad" value={bank.cpf} onChangeText={(v) => setBank({ ...bank, cpf: v })} />
          <View style={{ flexDirection: 'row', gap: spacing.md }}>
            <Input containerStyle={{ flex: 1 }} placeholder="Banco" value={bank.bankName} onChangeText={(v) => setBank({ ...bank, bankName: v })} />
            <Input containerStyle={{ width: 100 }} placeholder="Agência" value={bank.agency} onChangeText={(v) => setBank({ ...bank, agency: v })} />
          </View>
          <Input placeholder="Conta" value={bank.account} onChangeText={(v) => setBank({ ...bank, account: v })} />
          <Button label="Salvar" variant="secondary" loading={savingKey === 'bank'} icon={<Save size={18} color={colors.textMuted} />} onPress={saveBank} />
        </View>
      </Card>

      {/* Preferences */}
      <Card>
        <SectionTitle colors={colors} icon={<Bell size={18} color={colors.primary} />} text="Preferências" />
        <ToggleRow
          colors={colors}
          icon={<Bell size={20} color={colors.textMuted} />}
          label="Alertas sonoros"
          value={prefs.soundAlerts}
          onValueChange={(v) => setPref({ soundAlerts: v })}
        />
        <ToggleRow
          colors={colors}
          icon={<Moon size={20} color={colors.textMuted} />}
          label="Modo escuro"
          value={prefs.darkMode}
          onValueChange={(v) => setPref({ darkMode: v })}
        />
        <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingVertical: spacing.sm }}>
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }}>
            <Navigation size={20} color={colors.textMuted} />
            <Text style={{ color: colors.text, fontWeight: font.semibold }}>App de navegação</Text>
          </View>
          <View style={{ flexDirection: 'row', gap: 6 }}>
            {(['google', 'waze'] as const).map((n) => {
              const active = prefs.navApp === n;
              return (
                <Pressable
                  key={n}
                  onPress={() => setPref({ navApp: n })}
                  style={{
                    paddingHorizontal: 14,
                    paddingVertical: 8,
                    borderRadius: radius.full,
                    backgroundColor: active ? colors.primary : colors.cardMuted,
                  }}
                >
                  <Text style={{ color: active ? '#FFFFFF' : colors.textMuted, fontWeight: font.bold, fontSize: fontSize.sm }}>
                    {n === 'google' ? 'Google Maps' : 'Waze'}
                  </Text>
                </Pressable>
              );
            })}
          </View>
        </View>
      </Card>

      <Button
        label="Sair da conta"
        variant="danger"
        icon={<LogOut size={18} color="#FFFFFF" />}
        onPress={() =>
          Alert.alert('Sair', 'Deseja realmente sair?', [
            { text: 'Cancelar', style: 'cancel' },
            { text: 'Sair', style: 'destructive', onPress: logout },
          ])
        }
      />
      <View style={{ height: 20 }} />
    </Screen>
  );
}

function SectionTitle({ colors, icon, text }: { colors: any; icon: React.ReactNode; text: string }) {
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: spacing.md }}>
      {icon}
      <Text style={{ color: colors.text, fontWeight: font.black, fontSize: fontSize.lg }}>{text}</Text>
    </View>
  );
}

function ToggleRow({
  colors,
  icon,
  label,
  value,
  onValueChange,
}: {
  colors: any;
  icon: React.ReactNode;
  label: string;
  value: boolean;
  onValueChange: (v: boolean) => void;
}) {
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingVertical: spacing.sm }}>
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }}>
        {icon}
        <Text style={{ color: colors.text, fontWeight: font.semibold }}>{label}</Text>
      </View>
      <Switch
        value={value}
        onValueChange={onValueChange}
        trackColor={{ false: colors.border, true: colors.primary }}
        thumbColor="#FFFFFF"
      />
    </View>
  );
}
