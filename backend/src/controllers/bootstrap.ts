import type { Context } from "hono";
import { getBootstrapData } from "../services/server-data";
import { requireServerContext } from "../services/server-auth";

export async function getBootstrap(c: Context) {
  const context = await requireServerContext(c.req.raw);
  const data = await getBootstrapData(context);
  return c.json(data, {
    headers: {
      "cache-control": "private, no-store",
    },
  });
}
