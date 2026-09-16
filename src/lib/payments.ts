/**
 * Client do servidor de pagamentos da plataforma (repo nexmarket--Empresa,
 * pasta server/). O entregador usa os endpoints de recebedor Pagar.me:
 * cadastro (KYC + conta bancária) e consulta de status. Os repasses em si
 * são executados pelo painel Empresa na aprovação do saque
 * (POST /api/payouts/transfer) — este app só mostra se o cadastro está
 * pronto para recebê-los.
 */
import { auth } from './firebase';

export function paymentsApiUrl(): string {
  return (process.env.EXPO_PUBLIC_PAYMENTS_API_URL || '').trim().replace(/\/$/, '');
}

export function paymentsConfigured(): boolean {
  return paymentsApiUrl().length > 0;
}

async function api<T>(path: string, init?: RequestInit): Promise<T> {
  const base = paymentsApiUrl();
  if (!base) throw new Error('Servidor de pagamentos não configurado.');
  const token = await auth.currentUser?.getIdToken();
  if (!token) throw new Error('É necessário estar logado.');
  const res = await fetch(`${base}${path}`, {
    ...init,
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}`, ...(init?.headers || {}) },
  });
  const body = await res.json().catch(() => ({}));
  if (!res.ok) {
    const err: any = new Error(body?.error || `Servidor de pagamentos respondeu ${res.status}.`);
    err.paymentsUnavailable = !!body?.paymentsUnavailable;
    throw err;
  }
  return body as T;
}

export interface RecipientStatus {
  configured: boolean;
  recipientId?: string;
  status?: string;
}

/** Situação do cadastro de recebedor Pagar.me do entregador logado. */
export function getRecipientStatus(): Promise<RecipientStatus> {
  return api<RecipientStatus>('/api/recipients/driver/status');
}

export interface RecipientBankInput {
  holderName: string;
  holderDocument?: string;
  /** Código do banco (3 dígitos, ex: 260 = Nubank, 341 = Itaú). */
  bank: string;
  branchNumber: string;
  branchCheckDigit?: string;
  accountNumber: string;
  accountCheckDigit: string;
  accountType: 'checking' | 'savings';
}

export interface RecipientInput {
  document: string; // CPF, só dígitos
  name: string;
  email: string;
  birthdate: string; // AAAA-MM-DD
  monthlyIncome?: number;
  occupation?: string;
  bank: RecipientBankInput;
}

/** Cadastra (ou recadastra) o recebedor Pagar.me do entregador — KYC + conta bancária. */
export function registerRecipient(input: RecipientInput): Promise<{ ok: boolean; recipientId: string; status: string }> {
  return api('/api/recipients/driver', { method: 'POST', body: JSON.stringify(input) });
}

/**
 * Push transacional para o cliente (token viaja no pedido). Fire-and-forget:
 * nunca bloqueia o fluxo de entrega.
 */
export async function sendPush(to: string | null | undefined, title: string, body: string): Promise<void> {
  if (!to || !paymentsConfigured()) return;
  try {
    await api('/api/notifications/send', { method: 'POST', body: JSON.stringify({ to, title, body }) });
  } catch {
    // silencioso — push é melhoria, não requisito do fluxo
  }
}
