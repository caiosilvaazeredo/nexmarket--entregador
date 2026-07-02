# 📘 Manual — Nexmarket Entregador (app do motorista · Expo/React Native)

App do entregador: fica online, recebe ofertas de entrega, navega até a loja e o
cliente, colhe prova de entrega e acompanha ganhos na **Carteira** — com saques via
PIX (manual) ou **repasse automático via Stripe Connect**.

## 🧩 Integração com os outros sistemas

Os 4 apps usam o **mesmo projeto Firebase** (config em `firebase-config.json`):

- Pedidos prontos na **Loja** entram no pool de ofertas deste app.
- O **Cliente** acompanha a localização do entregador em tempo real.
- Saques solicitados aqui são aprovados no painel **Empresa**; com Stripe Connect
  configurado, o dinheiro é transferido automaticamente pela plataforma.

## ▶️ Rodar localmente

Requisitos: **Node.js 18+**, npm e o app **Expo Go** no celular (ou emulador).

```bash
npm install
cp .env.example .env        # opcional: ver Pagamentos abaixo
npm start                   # abre o Expo; escaneie o QR com o Expo Go
```

Atalhos: `npm run android` · `npm run ios` · `npm run web` · `npm run lint` (typecheck).

### Habilitar o recebimento via Stripe Connect (opcional)

1. Suba o servidor de pagamentos (repo `nexmarket--Empresa`, pasta `server/`).
2. No `.env` deste app:
   ```
   EXPO_PUBLIC_PAYMENTS_API_URL="http://192.168.0.10:8787"   # IP da sua máquina ou túnel
   ```
3. Na aba **Carteira** aparece o cartão "Recebimento automático" → *Configurar
   recebimento* abre o onboarding da Stripe (dados bancários, identidade).
4. Depois do onboarding, os saques aprovados no painel Empresa caem direto na conta.

> Pré-requisito da plataforma: Stripe **Connect** habilitado na conta
> (https://dashboard.stripe.com/connect, tipo Express). Sem Connect, os saques seguem
> o fluxo manual (a Empresa paga por PIX e marca como pago).

## 🏗️ Build (renderizar)

Projeto **Expo SDK 52** (managed) — binários pelo **EAS Build**:

```bash
npm i -g eas-cli
eas login
eas build:configure

eas build -p android --profile preview      # APK de teste
eas build -p android --profile production   # AAB para a Play Store
eas build -p ios --profile production       # iOS (conta Apple Developer)
```

> Variáveis `EXPO_PUBLIC_*` são embutidas no build — defina-as por perfil no
> `eas.json` ou com `eas secret:create`.

## 🚀 Publicar

1. **Lojas**: `eas submit -p android` / `eas submit -p ios`.
2. **Atualização OTA** (só JS): `eas update --branch production --message "ajustes"`.
3. Antes de produção: URL pública (https) em `EXPO_PUBLIC_PAYMENTS_API_URL`,
   Google Maps API key configurada e `firestore.rules` publicadas (repo Empresa).

## 💰 Carteira e pagamentos

- **Ganhos**: cada entrega concluída credita `driverEarnings` **+ gorjeta** no saldo
  (gorjeta é 100% do entregador). Gorjetas pós-entrega entram automaticamente ao
  abrir a Carteira.
- **Saque manual**: Carteira → *Solicitar saque* (usa a chave PIX do Perfil). A Empresa
  aprova e paga; o status muda para "Pago".
- **Stripe Connect**: com o onboarding concluído, a aprovação do saque no painel
  dispara uma **transferência real** para a conta bancária do entregador (o histórico
  mostra "Stripe Connect").

## ✨ Outras funcionalidades (ver ROADMAP.md no repo Empresa)

- **Oferta estilo Uber**: contagem regressiva circular, ganho total, **R$/km** e
  gorjeta destacada.
- **PIN de entrega**: peça o código de 4 dígitos ao cliente ao finalizar; sem o
  código, a foto do comprovante é obrigatória.
- **Meta diária gamificada** na home e **níveis Bronze → Diamante** no Perfil
  (entregas + avaliação).
- **Central de segurança**: botão 🚨 Emergência na entrega (190/192 + compartilhar
  localização).
- **Navegação**: Waze ou Google Maps conforme a preferência do Perfil.

## 🆘 Problemas comuns

| Sintoma | Correção |
|---|---|
| Cartão "Recebimento automático" não aparece | preencha `EXPO_PUBLIC_PAYMENTS_API_URL` e reinicie o Expo |
| Onboarding retorna erro | Connect não habilitado na conta Stripe da plataforma |
| Saque aprovado mas sem transferência | entregador sem onboarding concluído → pago manualmente |
| Mapa cinza no Android | configure a Google Maps API key no `.env` e `app.json` |
