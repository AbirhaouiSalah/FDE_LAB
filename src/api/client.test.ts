import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { getJson } from './client';

describe('api/client — getJson', () => {
  const originalFetch = globalThis.fetch;

  beforeEach(() => {
    vi.restoreAllMocks();
  });

  afterEach(() => {
    globalThis.fetch = originalFetch;
  });

  it('retourne le JSON parsé en cas de succès', async () => {
    globalThis.fetch = vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
      json: async () => ({ value: 42 })
    }) as unknown as typeof fetch;

    const result = await getJson<{ value: number }>('/kpis');
    expect(result).toEqual({ value: 42 });
  });

  it('envoie les credentials: include', async () => {
    const spy = vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
      json: async () => ({})
    });
    globalThis.fetch = spy as unknown as typeof fetch;

    await getJson('/kpis');
    expect(spy).toHaveBeenCalledWith(
      expect.stringContaining('/kpis'),
      expect.objectContaining({ credentials: 'include' })
    );
  });

  it('throw une erreur avec le status en cas de 4xx', async () => {
    globalThis.fetch = vi.fn().mockResolvedValue({
      ok: false,
      status: 403,
      json: async () => ({})
    }) as unknown as typeof fetch;

    await expect(getJson('/kpis')).rejects.toThrow(/403/);
  });

  it('throw une erreur avec le status en cas de 5xx', async () => {
    globalThis.fetch = vi.fn().mockResolvedValue({
      ok: false,
      status: 500,
      json: async () => ({})
    }) as unknown as typeof fetch;

    await expect(getJson('/kpis')).rejects.toThrow(/500/);
  });

  it('propage les erreurs réseau', async () => {
    globalThis.fetch = vi.fn().mockRejectedValue(new Error('network')) as unknown as typeof fetch;

    await expect(getJson('/kpis')).rejects.toThrow('network');
  });
});
