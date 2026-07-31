import { config } from "dotenv";
import { resolve } from "node:path";
import { Hono } from "hono";
import { cors } from "hono/cors";
import { onError } from "./middlewares/error";

config({ path: resolve(import.meta.dir, "../.env") });

const { apiRoutes } = await import("./routes/index");

const app = new Hono();
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

const port = Number(process.env.PORT ?? 3001);

console.log(`Hisaab API listening on http://localhost:${port}`);

export default {
  port,
  fetch: app.fetch,
};
