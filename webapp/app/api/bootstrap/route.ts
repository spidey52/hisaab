import { getBootstrapData } from "@/lib/server-data";
import {
  handleRouteError,
  requireServerContext,
} from "@/lib/server-auth";

export const dynamic = "force-dynamic";

export async function GET() {
  try {
    const context = await requireServerContext();
    const data = await getBootstrapData(context);
    return Response.json(data, {
      headers: {
        "cache-control": "private, no-store",
      },
    });
  } catch (error) {
    return handleRouteError(error);
  }
}
