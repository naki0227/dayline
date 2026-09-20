export type Env = Record<string, never>;

interface RequestLike {
  readonly method: string;
  readonly url: string;
}

export function handleRequest(request: RequestLike): Response {
  const url = new URL(request.url);
  if (request.method === "GET" && url.pathname === "/health") {
    return Response.json({ status: "ok" });
  }
  return new Response(null, { status: 404 });
}

const worker: ExportedHandler<Env> = {
  fetch(request): Response {
    return handleRequest(request);
  },
};

export default worker;
