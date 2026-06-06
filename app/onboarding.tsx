import React, { useState } from 'react';
import { View, Text, Pressable, Image, Alert, ActivityIndicator } from 'react-native';
import { Bike, Car, Truck, User, Phone, FileText, IdCard, Camera, Check, LogOut } from 'lucide-react-native';

import { Screen } from '../src/components/ui/Screen';
import { Card } from '../src/components/ui/Card';
import { Input } from '../src/components/ui/Input';
import { Button } from '../src/components/ui/Button';
import { useColors } from '../src/hooks/useColors';
import { font, fontSize, radius, spacing } from '../src/lib/theme';
import { useDriverStore } from '../src/store/useDriverStore';
import { createDriverProfile, updateDriverProfile } from '../src/lib/drivers';
import { logout } from '../src/lib/firebase';
import { pickImage } from '../src/lib/images';
import type { VehicleType } from '../src/lib/types';

const VEHICLES: { type: VehicleType; label: string; icon: any }[] = [
  { type: 'moto', label: 'Moto', icon: Bike },
  { type: 'carro', label: 'Carro', icon: Car },
  { type: 'bike', label: 'Bike', icon: Bike },
  { type: 'van', label: 'Van', icon: Truck },
];

export default function Onboarding() {
  const { colors } = useColors();
  const authUser = useDriverStore((s) => s.authUser);

  const [name, setName] = useState('');
  const [phone, setPhone] = useState('');
  const [vtype, setVtype] = useState<VehicleType>('moto');
  const [plate, setPlate] = useState('');
  const [model, setModel] = useState('');
  const [cnh, setCnh] = useState<string | null>(null);
  const [vehicleDoc, setVehicleDoc] = useState<string | null>(null);
  const [profile, setProfile] = useState<string | null>(null);
  const [uploadingKey, setUploadingKey] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  const pick = async (key: string, setter: (v: string) => void, camera = false) => {
    setUploadingKey(key);
    try {
      const uri = await pickImage({ camera, maxWidth: 1000, quality: 0.5 });
      if (uri) setter(uri);
      else if (uri === null) {
        // permission denied or cancelled — no-op
      }
    } catch {
      Alert.alert('Erro', 'Não foi possível processar a imagem.');
    } finally {
      setUploadingKey(null);
    }
  };

  const submit = async () => {
    if (!authUser) return;
    if (!name.trim()) return Alert.alert('Atenção', 'Informe seu nome completo.');
    if (!phone.trim()) return Alert.alert('Atenção', 'Informe seu telefone.');
    if (vtype !== 'bike' && !plate.trim())
      return Alert.alert('Atenção', 'Informe a placa do veículo.');

    setSaving(true);
    try {
      await createDriverProfile(authUser.uid, {
        name: name.trim(),
        email: authUser.email || '',
        phone: phone.trim(),
        vehicle: { type: vtype, plate: plate.trim().toUpperCase(), model: model.trim() },
        photoUrl: profile || '',
      });
      await updateDriverProfile(authUser.uid, {
        documents: {
          cnhUrl: cnh || '',
          vehicleDocUrl: vehicleDoc || '',
          profilePhotoUrl: profile || '',
          status: 'pending',
        },
      });
      // Gate routes to (tabs) once the profile snapshot arrives.
    } catch (e) {
      console.warn(e);
      Alert.alert('Erro', 'Não foi possível salvar seu cadastro. Tente novamente.');
    } finally {
      setSaving(false);
    }
  };

  return (
    <Screen
      title="Complete seu cadastro"
      subtitle="Precisamos de alguns dados para liberar suas entregas."
      right={
        <Pressable onPress={logout} hitSlop={10} style={{ padding: 8 }}>
          <LogOut size={22} color={colors.textMuted} />
        </Pressable>
      }
    >
      {/* Dados pessoais */}
      <Card>
        <SectionTitle colors={colors} icon={<User size={18} color={colors.primary} />} text="Dados pessoais" />
        <View style={{ gap: spacing.md }}>
          <Input
            placeholder="Nome completo"
            value={name}
            onChangeText={setName}
            icon={<User size={20} color={colors.textSubtle} />}
          />
          <Input
            placeholder="Telefone / WhatsApp"
            keyboardType="phone-pad"
            value={phone}
            onChangeText={setPhone}
            icon={<Phone size={20} color={colors.textSubtle} />}
          />
        </View>
      </Card>

      {/* Veículo */}
      <Card>
        <SectionTitle colors={colors} icon={<Bike size={18} color={colors.primary} />} text="Seu veículo" />
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
                <Icon size={22} color={active ? colors.primaryDark : colors.textMuted} />
                <Text
                  style={{
                    color: active ? colors.primaryDark : colors.textMuted,
                    fontWeight: font.bold,
                    fontSize: fontSize.xs,
                    marginTop: 4,
                  }}
                >
                  {v.label}
                </Text>
              </Pressable>
            );
          })}
        </View>
        <View style={{ gap: spacing.md }}>
          <Input placeholder="Placa (ex: ABC1D23)" autoCapitalize="characters" value={plate} onChangeText={setPlate} />
          <Input placeholder="Modelo (ex: Honda CG 160)" value={model} onChangeText={setModel} />
        </View>
      </Card>

      {/* Documentos */}
      <Card>
        <SectionTitle colors={colors} icon={<FileText size={18} color={colors.primary} />} text="Documentos" />
        <Text style={{ color: colors.textMuted, fontWeight: font.medium, marginBottom: spacing.md }}>
          Enviados para validação. Você pode começar e completar depois.
        </Text>
        <View style={{ gap: spacing.sm }}>
          <DocRow
            colors={colors}
            label="CNH"
            icon={<IdCard size={20} color={colors.accent} />}
            value={cnh}
            busy={uploadingKey === 'cnh'}
            onPick={() => pick('cnh', setCnh)}
          />
          <DocRow
            colors={colors}
            label="Documento do veículo"
            icon={<FileText size={20} color={colors.accent} />}
            value={vehicleDoc}
            busy={uploadingKey === 'vehicleDoc'}
            onPick={() => pick('vehicleDoc', setVehicleDoc)}
          />
          <DocRow
            colors={colors}
            label="Foto de perfil"
            icon={<Camera size={20} color={colors.accent} />}
            value={profile}
            busy={uploadingKey === 'profile'}
            onPick={() => pick('profile', setProfile, true)}
          />
        </View>
      </Card>

      <Button label="Concluir cadastro" size="lg" loading={saving} onPress={submit} />
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

function DocRow({
  colors,
  label,
  icon,
  value,
  busy,
  onPick,
}: {
  colors: any;
  label: string;
  icon: React.ReactNode;
  value: string | null;
  busy: boolean;
  onPick: () => void;
}) {
  return (
    <Pressable
      onPress={onPick}
      style={{
        flexDirection: 'row',
        alignItems: 'center',
        gap: 12,
        padding: 12,
        borderRadius: radius.md,
        borderWidth: 2,
        borderColor: value ? colors.primary : colors.border,
        backgroundColor: value ? colors.primarySoft : colors.cardMuted,
      }}
    >
      {value ? (
        <Image source={{ uri: value }} style={{ width: 44, height: 44, borderRadius: 8 }} />
      ) : (
        <View
          style={{
            width: 44,
            height: 44,
            borderRadius: 8,
            backgroundColor: colors.card,
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          {icon}
        </View>
      )}
      <View style={{ flex: 1 }}>
        <Text style={{ color: colors.text, fontWeight: font.bold }}>{label}</Text>
        <Text style={{ color: value ? colors.primaryDark : colors.textMuted, fontWeight: font.medium, fontSize: fontSize.sm }}>
          {value ? 'Enviado • toque para trocar' : 'Toque para enviar'}
        </Text>
      </View>
      {busy ? (
        <ActivityIndicator color={colors.primary} />
      ) : value ? (
        <Check size={22} color={colors.primary} />
      ) : null}
    </Pressable>
  );
}
