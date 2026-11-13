import { vi } from "vitest";

type Reply = { status?: number; body?: unknown; headers?: Record<string, string> };
type Handler = Reply | ((init: RequestInit, url: string) => Reply);

// A fake fetch keyed by "METHOD /path". Unknown routes fail the test loudly.
export function fakeFetch(routes: Record<string, Handler>) {
  return vi.fn(async (url: string, init: RequestInit = {}) => {
    const path = url.replace(/^https?:\/\/[^/]+/, "");
    const key = `${init.method ?? "GET"} ${path}`;
    const handler = routes[key];
    if (!handler) throw new Error(`unexpected request ${key}`);
    const reply = typeof handler === "function" ? handler(init, url) : handler;
    const status = reply.status ?? 200;
    const noBody = status === 204 || status === 202 || reply.body === undefined;
    return new Response(noBody ? null : JSON.stringify(reply.body), { status, headers: reply.headers });
  });
}

export const errorBody = (code: string) => ({ error: { code, message: "x" } });
