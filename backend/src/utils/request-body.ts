import { HttpError } from "./security";

const DEFAULT_JSON_LIMIT_BYTES = 64 * 1024;

export async function readJsonBody<T>(
  request: Request,
  maximumBytes = DEFAULT_JSON_LIMIT_BYTES,
): Promise<T> {
  const contentType = request.headers
    .get("content-type")
    ?.split(";", 1)[0]
    ?.trim()
    .toLowerCase();
  if (contentType !== "application/json") {
    throw new HttpError("Send this request as JSON.", 415);
  }

  const declaredLength = Number(request.headers.get("content-length"));
  if (Number.isFinite(declaredLength) && declaredLength > maximumBytes) {
    throw new HttpError("That request is too large.", 413);
  }
  if (!request.body) {
    throw new HttpError("A JSON request body is required.", 400);
  }

  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let totalBytes = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    totalBytes += value.byteLength;
    if (totalBytes > maximumBytes) {
      await reader.cancel();
      throw new HttpError("That request is too large.", 413);
    }
    chunks.push(value);
  }

  const bytes = new Uint8Array(totalBytes);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }

  try {
    return JSON.parse(new TextDecoder().decode(bytes)) as T;
  } catch {
    throw new HttpError("Send a valid JSON request body.", 400);
  }
}
