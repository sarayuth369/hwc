import { supabase } from "./supabase";

const WORKER_BASE_URL = import.meta.env.VITE_WORKER_BASE_URL;

export class AdminApiError extends Error {
  constructor(
    message: string,
    public status: number,
    public code?: string
  ) {
    super(message);
  }
}

async function authHeader(): Promise<Record<string, string>> {
  const { data } = await supabase.auth.getSession();
  const token = data.session?.access_token;
  if (!token) throw new AdminApiError("Not signed in", 401);
  return { Authorization: `Bearer ${token}` };
}

async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
  const headers = {
    "Content-Type": "application/json",
    ...(await authHeader()),
    ...(init.headers ?? {}),
  };
  const response = await fetch(`${WORKER_BASE_URL}${path}`, { ...init, headers });
  const body = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new AdminApiError(
      body.error ?? `Request failed (${response.status})`,
      response.status,
      body.code
    );
  }
  return body as T;
}

export interface DashboardMetrics {
  totalUsers: number;
  activeUsers: number;
  suspendedUsers: number;
  deletedUsers: number;
  confirmedUsers: number;
  unconfirmedUsers: number;
  newUsersLast7Days: number;
  newUsersLast30Days: number;
  aiUsage: null;
  recentActivity: Array<{
    action: string;
    targetType: string;
    targetId: string | null;
    createdAt: string;
  }>;
  serviceStatus: { worker: "ok"; supabaseAdminApi: "ok" | "error" };
}

export interface AdminUserRow {
  id: string;
  email: string | null;
  displayName: string | null;
  status: "active" | "suspended" | "deleted";
  isAdmin: boolean;
  emailConfirmed: boolean;
  createdAt: string;
  lastSignInAt: string | null;
  bannedUntil: string | null;
}

export interface ListUsersResult {
  rows: AdminUserRow[];
  total: number;
  page: number;
  pageSize: number;
}

export interface AuditLogRow {
  id: string;
  adminUserId: string;
  action: string;
  targetType: string;
  targetId: string | null;
  metadata: Record<string, unknown>;
  createdAt: string;
}

export interface AuditLogListResult {
  rows: AuditLogRow[];
  total: number;
  page: number;
  pageSize: number;
}

export const adminApi = {
  getDashboard: () => request<DashboardMetrics>("/api/admin/dashboard"),

  listUsers: (params: {
    search?: string;
    status?: string;
    sortBy?: string;
    sortDir?: string;
    page: number;
    pageSize: number;
  }) => {
    const qs = new URLSearchParams();
    if (params.search) qs.set("search", params.search);
    if (params.status) qs.set("status", params.status);
    if (params.sortBy) qs.set("sortBy", params.sortBy);
    if (params.sortDir) qs.set("sortDir", params.sortDir);
    qs.set("page", String(params.page));
    qs.set("pageSize", String(params.pageSize));
    return request<ListUsersResult>(`/api/admin/users?${qs.toString()}`);
  },

  getUser: (id: string) => request<AdminUserRow>(`/api/admin/users/${id}`),

  updateUserDisplayName: (id: string, displayName: string) =>
    request<AdminUserRow>(`/api/admin/users/${id}`, {
      method: "PATCH",
      body: JSON.stringify({ displayName }),
    }),

  suspendUser: (id: string) =>
    request<{ success: true }>(`/api/admin/users/${id}/suspend`, { method: "POST" }),

  unsuspendUser: (id: string) =>
    request<{ success: true }>(`/api/admin/users/${id}/unsuspend`, { method: "POST" }),

  deleteUser: (id: string) =>
    request<{ success: true }>(`/api/admin/users/${id}`, { method: "DELETE" }),

  listAuditLog: (params: { page: number; pageSize: number; action?: string }) => {
    const qs = new URLSearchParams();
    qs.set("page", String(params.page));
    qs.set("pageSize", String(params.pageSize));
    if (params.action) qs.set("action", params.action);
    return request<AuditLogListResult>(`/api/admin/audit-log?${qs.toString()}`);
  },
};
