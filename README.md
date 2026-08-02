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
| Onboarding: dados pessoais (com CPF) + veículo | `lib/screens/onboarding.dart` |
| **Envio de documentos** (CNH, CRLV, foto, comprovante) e acompanhamento da análise | `lib/screens/documents_screen.dart`, `lib/services/documents_repo.dart` |
| **Só recebe corridas após aprovação no app da Empresa** | `DriverProfile.isApproved`, gate em `DriversRepo.setOnline` e no `main.dart` |
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

---

## 🧪 Testes e builds

```bash
flutter test         # 12 testes: modelos, ganhos e a jornada completa da
                     # corrida (Firestore fake em memória)
flutter analyze      # 0 issues
flutter build apk    # APK release Android
flutter build web    # versão para navegador (teste com: python3 -m http.server -d build/web)
```

O build web usa **CanvasKit e fontes auto-hospedados**; para deploy copie o
CanvasKit do SDK:

```bash
flutter build web --release && cp -r "$(dirname "$(which flutter)")/cache/flutter_web_sdk/canvaskit" build/web/canvaskit
```

> No navegador o GPS usa a API de geolocalização do browser (exige HTTPS ou
> localhost). Deep-links de navegação abrem o Google Maps/Waze em nova aba.

Os testes de jornada (`test/journey_test.dart`) semeiam o pedido com o payload
exato do checkout do app do cliente e verificam: oferta no pool, aceite
transacional (anti-corrida), ciclo de status, POD, crédito de carteira com
gorjeta, problemas/devolução ao pool e saque via PIX.

---

## 🪪 Cadastro, documentos e aprovação

O entregador **não entra em operação sozinho**: a conta nasce pendente e só
recebe corridas depois de aprovada no **app da Empresa**
(`nexmarket--Empresa` → Entregadores).

```
1. Cadastro (e-mail/senha) → onboarding: nome, celular, CPF e veículo
2. Envio dos documentos: CNH, documento do veículo (CRLV), foto de perfil
   e comprovante de residência
3. A Empresa analisa cada documento e aprova, recusa ou bloqueia a conta
4. Aprovado → o app libera o botão Online e as ofertas de corrida
```

Enquanto não houver aprovação, o app abre direto na tela de status do
cadastro (`PendingApprovalScreen`) e o botão *Online* permanece bloqueado com
a explicação do motivo.

**Contrato com o painel da Empresa** (`/drivers/{uid}`):

| Campo | Quem escreve | Uso |
|---|---|---|
| `documents.{cnhUrl,vehicleDocUrl,profilePhotoUrl,proofOfResidenceUrl}` | entregador | caminho do arquivo no Storage |
| `documents.status` | ambos | situação geral dos documentos |
| `documents.review.{cnh,vehicleDoc,profilePhoto,proofOfResidence}` | **Empresa** | parecer por documento + `rejectionReason` |
| `approvalStatus` (`pending`/`approved`/`rejected`/`blocked`) | **Empresa** | libera ou barra a operação |
| `blockedReason` | **Empresa** | motivo mostrado ao entregador |
| `cpf` | entregador | checagem de antecedentes / blacklist |

Os arquivos vão para o Firebase Storage em
`drivers/{uid}/documents/{chave}.jpg` e o Firestore guarda **o caminho**, não
uma URL pública — o painel gera um link assinado na hora de revisar. Quando um
documento é recusado, o entregador vê o motivo e reenvia apenas aquele
documento, o que devolve a conta para a fila de análise automaticamente.

> Para produção, publique também as *Security Rules* do Storage restringindo
> `drivers/{uid}/documents/**` ao próprio uid (escrita) e à equipe de
> operação (leitura).
