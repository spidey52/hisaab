export type BalanceKind = "receive" | "pay" | "settled";
export type EntryAction = "gave" | "received" | "opening_balance";
export type EntryStatus = "posted" | "cancelled";

export type Company = {
  id: string;
  name: string;
  currency: "INR";
  timezone: string;
  version: number;
  updatedAt: string;
};

export type AppUser = {
  id: string;
  phoneE164: string;
  fullName: string;
  language: "en" | "hi";
  accessibilityMode: boolean;
  contactDiscoverable: boolean;
  version: number;
};

export type Group = {
  id: string;
  name: string;
  version: number;
  updatedAt: string;
};

export type Party = {
  id: string;
  reference: string;
  name: string;
  shortName: string;
  phone: string;
  phoneE164: string | null;
  notes: string;
  groupId: string | null;
  groupName: string | null;
  balancePaise: number;
  transactionCount: number;
  archivedAt: string | null;
  createdAt: string;
  updatedAt: string;
  version: number;
};

export type Entry = {
  id: string;
  partyId: string;
  partyName: string;
  sequence: number;
  action: EntryAction;
  amountPaise: number;
  balanceEffectPaise: number;
  narration: string;
  entryDate: string;
  paymentAccount: string | null;
  status: EntryStatus;
  createdByName: string;
  createdAt: string;
  editedAt: string | null;
  cancelledAt: string | null;
  revisionCount: number;
  updatedAt: string;
  version: number;
  runningBalancePaise?: number;
  clientSync?: "waiting" | "failed";
};

export type BootstrapData = {
  user: AppUser;
  company: Company;
  companies: Company[];
  groups: Group[];
  parties: Party[];
  entries: Entry[];
  serverTime: string;
  syncCursor: string;
};

export type ApiError = {
  error: string;
  code?: string;
  duplicates?: Array<Pick<Party, "id" | "name" | "phone" | "reference">>;
};
