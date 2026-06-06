import React, { useEffect, useRef, useState } from 'react';
import {
  View,
  Text,
  TextInput,
  Pressable,
  FlatList,
  KeyboardAvoidingView,
  Platform,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { ArrowLeft, Send, Headset } from 'lucide-react-native';

import { useColors } from '../../src/hooks/useColors';
import { font, fontSize, radius, spacing } from '../../src/lib/theme';
import { formatTime } from '../../src/lib/format';
import { useDriverStore } from '../../src/store/useDriverStore';
import { subscribeMessages, sendMessage } from '../../src/lib/chat';
import type { ChatMessage } from '../../src/lib/types';

export default function Chat() {
  const { colors } = useColors();
  const router = useRouter();
  const params = useLocalSearchParams<{ id: string; sm?: string }>();
  const driver = useDriverStore((s) => s.driver);
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [text, setText] = useState('');
  const listRef = useRef<FlatList>(null);

  const smId = params.sm || '';
  const orderId = params.id || '';

  useEffect(() => {
    if (!smId || !orderId) return;
    const unsub = subscribeMessages(smId, orderId, setMessages);
    return unsub;
  }, [smId, orderId]);

  const send = async () => {
    const t = text.trim();
    if (!t || !driver) return;
    setText('');
    try {
      await sendMessage(smId, orderId, { text: t, senderId: driver.uid, senderRole: 'driver' });
    } catch {
      // best-effort; message will not appear if it failed
    }
  };

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: colors.bg }} edges={['top', 'bottom']}>
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, paddingHorizontal: spacing.md, paddingVertical: spacing.sm, borderBottomWidth: 1, borderBottomColor: colors.border }}>
        <Pressable onPress={() => router.back()} hitSlop={10} style={{ padding: 6 }}>
          <ArrowLeft size={24} color={colors.text} />
        </Pressable>
        <View style={{ width: 38, height: 38, borderRadius: 19, backgroundColor: colors.primarySoft, alignItems: 'center', justifyContent: 'center' }}>
          <Headset size={20} color={colors.primaryDark} />
        </View>
        <View>
          <Text style={{ color: colors.text, fontWeight: font.black, fontSize: fontSize.base }}>Chat do pedido</Text>
          <Text style={{ color: colors.textMuted, fontWeight: font.medium, fontSize: fontSize.xs }}>
            Loja & suporte • #{orderId.slice(0, 6).toUpperCase()}
          </Text>
        </View>
      </View>

      <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined} keyboardVerticalOffset={8}>
        <FlatList
          ref={listRef}
          data={messages}
          keyExtractor={(m) => m.id}
          contentContainerStyle={{ padding: spacing.lg, gap: spacing.sm, flexGrow: 1 }}
          onContentSizeChange={() => listRef.current?.scrollToEnd({ animated: true })}
          ListEmptyComponent={
            <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', paddingTop: 80 }}>
              <Text style={{ color: colors.textSubtle, fontWeight: font.medium, textAlign: 'center' }}>
                Envie uma mensagem para a loja ou o suporte sobre este pedido.
              </Text>
            </View>
          }
          renderItem={({ item }) => {
            const mine = item.senderRole === 'driver';
            return (
              <View style={{ alignSelf: mine ? 'flex-end' : 'flex-start', maxWidth: '82%' }}>
                <View
                  style={{
                    backgroundColor: mine ? colors.primary : colors.card,
                    borderWidth: mine ? 0 : 2,
                    borderColor: colors.border,
                    borderRadius: radius.lg,
                    paddingHorizontal: 14,
                    paddingVertical: 10,
                  }}
                >
                  {!mine ? (
                    <Text style={{ color: colors.textMuted, fontWeight: font.bold, fontSize: 10, marginBottom: 2 }}>
                      {item.senderRole === 'store' ? 'Loja' : item.senderRole === 'support' ? 'Suporte' : 'Cliente'}
                    </Text>
                  ) : null}
                  <Text style={{ color: mine ? '#fff' : colors.text, fontWeight: font.medium, fontSize: fontSize.base }}>
                    {item.text}
                  </Text>
                </View>
                <Text style={{ color: colors.textSubtle, fontSize: 10, marginTop: 2, alignSelf: mine ? 'flex-end' : 'flex-start' }}>
                  {formatTime(item.createdAt)}
                </Text>
              </View>
            );
          }}
        />

        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, padding: spacing.md, borderTopWidth: 1, borderTopColor: colors.border, backgroundColor: colors.card }}>
          <TextInput
            value={text}
            onChangeText={setText}
            placeholder="Escreva uma mensagem…"
            placeholderTextColor={colors.textSubtle}
            style={{
              flex: 1,
              backgroundColor: colors.cardMuted,
              borderRadius: radius.full,
              paddingHorizontal: 16,
              paddingVertical: 10,
              color: colors.text,
              fontWeight: font.medium,
              fontSize: fontSize.base,
            }}
            onSubmitEditing={send}
            returnKeyType="send"
          />
          <Pressable
            onPress={send}
            style={{ width: 46, height: 46, borderRadius: 23, backgroundColor: colors.primary, alignItems: 'center', justifyContent: 'center' }}
          >
            <Send size={20} color="#fff" />
          </Pressable>
        </View>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}
