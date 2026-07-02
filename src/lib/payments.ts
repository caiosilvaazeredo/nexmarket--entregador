/**
 * Client do servidor de pagamentos da plataforma (repo nexmarket--Empresa,
 * pasta server/). O entregador usa apenas os endpoints de Stripe Connect:
 * onboarding da conta de recebimento e consulta de status. Os repasses em si
 * são executados pelo painel Empresa na aprovação do saque.
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
    err.connectUnavailable = !!body?.connectUnavailable;
    throw err;
  }
  return body as T;
}

export interface ConnectStatus {
  configured: boolean;
  accountId?: string;
  payoutsEnabled?: boolean;
  detailsSubmitted?: boolean;
}

/** Situação da conta Stripe Connect do entregador logado. */
export function getConnectStatus(): Promise<ConnectStatus> {
  return api<ConnectStatus>('/api/connect/status');
}

/** Cria/recupera a conta Connect e devolve o link de onboarding da Stripe. */
export function createConnectOnboardingLink(): Promise<{ accountId: string; url: string }> {
  return api('/api/connect/account-link', { method: 'POST', body: JSON.stringify({}) });
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
