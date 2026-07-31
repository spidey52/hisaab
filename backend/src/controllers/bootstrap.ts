import type { Context } from "hono";
import { getBootstrapData } from "../services/server-data";
import {
  handleRouteError,
  requireServerContext,
} from "../services/server-auth";

export async function getBootstrap(c: Context) {
  try {
    const context = await requireServerContext(c.req.raw);
    const data = await getBootstrapData(context);
    return c.json(data, {
      headers: {
        "cache-control": "private, no-store",
      },
    });
  } catch (error) {
    return handleRouteError(error);
  }
}
