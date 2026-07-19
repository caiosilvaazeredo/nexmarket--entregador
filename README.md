# 🛵 Nexmarket Entregador (Flutter)

App do **entregador** da plataforma **Nexmarket**, no estilo *Uber Driver*,
**reescrito em Flutter** e totalmente integrado à loja (`nexmarket--loja`) e ao
app do cliente (`nexmarket--cliente`): todos compartilham o **mesmo projeto
Firebase e o mesmo banco Firestore (nomeado)**.

---

## 🚀 Como rodar

Pré-requisitos: **Flutter 3.32+** (`flutter doctor` sem erros) e um emulador
Android ou dispositivo físico.

```bash
flutter pub get
flutter run          # escolha o dispositivo (a para Android)
```

Não precisa de `google-services.json`: a configuração do Firebase é passada em
código (`lib/firebase_options.dart`), incluindo o **banco Firestore nomeado**.

```bash
flutter analyze      # checagem estática (sem erros)
flutter build apk    # build de produção Android
```

## ✨ Funcionalidades

| Funcionalidade | Onde |
|---|---|
| Cadastro + login + recuperação de senha | `lib/screens/auth.dart` |
| Onboarding: dados pessoais + veículo (docs ficam `pending` p/ aprovação) | `lib/screens/onboarding.dart` |
| Painel com botão **Online/Offline** + resumo de ganhos | `lib/screens/home_screen.dart` |
| Oferta com **timer de 30 s**, distâncias, ganho e itens | `_OfferCard` em `home_screen.dart` |
| Aceite com **transação anti-corrida** | `OrdersRepo.acceptOrder` |
| Fluxo: navegar à loja → cheguei → coletei → navegar ao cliente | `lib/screens/delivery_screen.dart` |
| Navegação por **Google Maps ou Waze** (deep-link, sem API key) | `delivery_screen.dart` + preferência no perfil |
| **Comprovante (POD)**: PIN do cliente + quem recebeu + observação | `delivery_screen.dart` |
| Reportar problemas (endereço, ausente, danificado…) / devolver ao pool | `delivery_screen.dart` |
| Chat da corrida (loja/cliente) + ligar para o cliente | `lib/screens/chat_screen.dart` |
| Histórico de entregas | `lib/screens/deliveries_screen.dart` |
| Carteira: saldo, ganhos dia/semana/mês, **saque via PIX** | `lib/screens/wallet_screen.dart` |
| Perfil: veículo, dados bancários, som, modo escuro, app de navegação | `lib/screens/profile_screen.dart` |

**Não funcionais**

- **Bateria/privacidade**: o GPS só é publicado enquanto Online/em corrida,
  com filtro de 50 m (`lib/services/location_service.dart`).
- **Tempo real**: ofertas e corridas chegam por listeners do Firestore; o
  cache offline do SDK segura ações em queda de rede.
- **Anti-corrida**: aceite dentro de `runTransaction` — dois entregadores
  nunca pegam o mesmo pedido.

## 🔗 Integração com o banco compartilhado

```
/drivers/{uid}                              ← perfil (este app)
/drivers/{uid}/payouts/{id}                 ← saques
/supermarkets/{smId}/orders/{orderId}       ← pedidos (+ campos de entrega)
/supermarkets/{smId}/orders/{id}/messages   ← chat
```

Ciclo (compartilhado com a loja): `pending → picking → ready` → entregador
assume (`deliveryStatus: awaiting_driver → going_to_store → arrived_store →
going_to_customer → delivered`, com `status: delivered` ao final) — idêntico
ao app Expo anterior, então painel da loja e app do cliente seguem
funcionando sem mudanças.

> ⚠️ As **Security Rules** e os índices dos *collection group queries*
> (`orders` por `status`+`deliveryStatus` e por `driverId`) continuam no
> repositório `nexmarket--loja`. Na primeira execução o Firestore pode sugerir
> a criação dos índices — use o link do erro no console.
