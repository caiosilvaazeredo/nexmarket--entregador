# 🛵 Nexmarket Entregador

App do entregador da plataforma **Nexmarket**, no estilo *Uber Driver*, **totalmente
integrado** ao app da loja (`nexmarket--loja`): os dois compartilham o **mesmo
projeto Firebase e o mesmo banco Firestore**.

Construído em **Expo / React Native + TypeScript**, gera builds nativos para
**Android e iOS** a partir de uma única base de código, reaproveitando a
identidade visual "Duolingo" da loja (verde `#58CC02`, botões 3D, tipografia
forte, alto contraste para uso sob sol).

---

## ✨ Funcionalidades

| Requisito | Onde |
|---|---|
| Cadastro (e-mail) + login + recuperação de senha | `app/(auth)/*` |
| Onboarding: documentos (CNH, doc. do veículo, foto) + dados do veículo | `app/onboarding.tsx` |
| Painel com botão **Online/Offline**, resumo de ganhos e mapa | `app/(tabs)/index.tsx` |
| Oferta de pedido com **timer de 30s**, distâncias, ganho e itens (alerta sonoro/visual) | `src/components/OfferModal.tsx` |
| Aceite/recusa com **transação anti-corrida** | `src/lib/orders.ts` |
| Coleta (navegar à loja → cheguei → coletei) | `app/delivery/[id].tsx` |
| Entrega (navegação Google Maps/Waze) | `src/lib/geo.ts` |
| **Comprovante (POD)**: assinatura digital + foto do pacote | `src/components/SignaturePad.tsx` |
| Reportar problemas (endereço, ausente, danificado…) | `app/delivery/[id].tsx` |
| Chat do pedido (loja/suporte) + ligação para o cliente | `app/chat/[id].tsx` |
| Histórico de entregas | `app/(tabs)/deliveries.tsx` |
| Carteira: ganhos (dia/semana/mês) + **solicitar saque** | `app/(tabs)/wallet.tsx` |
| Perfil: dados pessoais, bancários e preferências (som, tema, app de navegação) | `app/(tabs)/profile.tsx` |

**Não funcionais**

- **Bateria/privacidade:** rastreamento só quando *Online*/em corrida, com filtro de
  distância (50m), intervalo de 15s e *deferred updates* (`src/lib/location.ts`).
- **Offline-first:** ações críticas (chegar, coletar, finalizar) são salvas
  localmente e sincronizadas ao reconectar (`src/lib/offlineQueue.ts`).
- **Segurança:** todo tráfego via HTTPS/TLS do SDK Firebase; acesso ao banco
  mediado por *Security Rules* (nenhum acesso direto a SQL/Cloud).
- **UX:** botões primários grandes na base da tela, alto contraste, modo escuro.
- **Cross-platform:** Android + iOS pela mesma base (Expo).

---

## 🔗 Integração com o `nexmarket--loja`

Ambos os apps usam o `firebase-config.json` apontando para o mesmo projeto e a
mesma base nomeada do Firestore.

```
/drivers/{uid}                              ← perfil do entregador (este app)
/drivers/{uid}/payouts/{id}                 ← saques
/supermarkets/{smId}                        ← loja (leitura)
/supermarkets/{smId}/settings/main          ← endereço/geo da loja (leitura)
/supermarkets/{smId}/deliveryConfig/main    ← config de entrega (leitura)
/supermarkets/{smId}/orders/{orderId}       ← pedidos (+ campos de entrega)
/supermarkets/{smId}/orders/{id}/messages   ← chat do pedido
```

Ciclo do pedido (compartilhado com a loja):
`pending → picking → ready` (loja separa) → entregador assume
(`deliveryStatus: awaiting_driver → going_to_store → arrived_store →
going_to_customer → delivered`, com `status: delivered` ao final).

> ⚠️ As **Security Rules** e o **checkout com endereço** ficam no repositório
> `nexmarket--loja` (foram atualizados lá nesta mesma entrega). Faça o deploy das
> regras antes de usar este app em produção.

---

## 🚀 Como rodar

Pré-requisitos: **Node 18+** e o app **Expo Go** (para teste rápido) ou um
**Dev Build** (recomendado, por causa do mapa e do rastreamento em background).

```bash
npm install
npx expo start          # abra no Expo Go (mapa cai em placeholder)
```

### Dev Build (mapa + GPS em background funcionando)

```bash
npm install -g eas-cli
eas login
eas build --profile development --platform android   # ou ios
# instale o APK/IPA gerado e rode:
npx expo start --dev-client
```

### Build de produção (lojas)

```bash
eas build --profile production --platform android
eas build --profile production --platform ios
```

---

## ⚙️ Configuração necessária

1. **Mapa (Google Maps):** crie uma API key e coloque em `app.json`
   (`android.config.googleMaps.apiKey` e `ios.config.googleMapsApiKey`).
   Sem a key, o app continua funcionando com um *placeholder* de mapa; a
   navegação por Google Maps/Waze (deep-link) funciona mesmo assim.
2. **Login anônimo** ("Quero apenas testar"): habilite *Anonymous* em
   Firebase Auth.
3. **Security Rules:** publique o `firestore.rules` do repositório da loja
   (já contém `drivers`, campos de entrega e `messages`).
4. **Índices Firestore:** na primeira execução, os *collection group queries*
   (`orders` por `status`+`deliveryStatus` e por `driverId`) vão sugerir a
   criação de índices — clique no link do erro para criá-los.
5. **Push em background (opcional):** para receber ofertas com o app fechado,
   configure FCM/APNs. As ofertas com o app aberto já funcionam via listener +
   notificação local.

---

## 🧱 Estrutura

```
app/                 # rotas (expo-router)
  (auth)/            # login, cadastro, recuperação
  onboarding.tsx     # documentos + veículo
  (tabs)/            # início, entregas, carteira, perfil
  delivery/[id].tsx  # fluxo da entrega + POD + problemas
  chat/[id].tsx      # chat do pedido
src/
  lib/               # firebase, orders, drivers, location, offlineQueue, geo…
  components/         # OfferModal, SignaturePad, MapPanel, UI kit…
  store/             # estado global (zustand)
  hooks/             # tema
```

Stack: Expo SDK 52 · React Native 0.76 · expo-router · Firebase JS SDK ·
Zustand · react-native-maps · expo-location · react-native-svg ·
lucide-react-native.
