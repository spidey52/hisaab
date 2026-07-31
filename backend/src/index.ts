import { Hono } from "hono";
import { cors } from "hono/cors";
import { logger } from "hono/logger";
import { env } from "./config/env";
import { onError } from "./middlewares/error";

const { apiRoutes } = await import("./routes/index");

const app = new Hono();
app.use(logger())
app.onError(onError);

app.use(
  "*",
  cors({
    origin: "*",
    allowHeaders: ["Authorization", "Content-Type"],
    allowMethods: ["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
  }),
);

app.route("/api", apiRoutes);

const port = env.PORT;

console.log(`Hisaab API listening on http://localhost:${port}`);

export default {
  port,
  fetch: app.fetch,
};
