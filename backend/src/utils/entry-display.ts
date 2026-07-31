export function entryDisplayLabel(action: unknown, narration: unknown) {
  const note = String(narration ?? "").trim();
  if (note) return note;
  if (action === "opening_balance") return "Opening balance";
  return action === "received" ? "You got" : "You gave";
}
