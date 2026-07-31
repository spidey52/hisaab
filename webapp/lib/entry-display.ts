export function entryDisplayLabel(action: unknown, narration: unknown) {
  const note = String(narration ?? "").trim();
  if (note) return note;
  if (action === "opening_balance") return "Opening balance";
  return action === "received" ? "You got" : "You gave";
}

export function entryDirectionTone(action: unknown) {
  if (action === "gave") return "gave";
  if (action === "received") return "received";
  return "opening";
}

export function entryDirectionLabel(
  action: unknown,
  balanceEffectPaise = 0,
) {
  if (action === "gave") return "You gave";
  if (action === "received") return "You got";
  if (balanceEffectPaise > 0) return "They owe you";
  if (balanceEffectPaise < 0) return "You owe them";
  return "Opening balance";
}

export function entryAmountSign(action: unknown) {
  if (action === "gave") return "−";
  if (action === "received") return "+";
  return "";
}
