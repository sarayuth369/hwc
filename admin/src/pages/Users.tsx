import { useEffect, useState, useCallback } from "react";
import { Link } from "react-router-dom";
import { adminApi, AdminUserRow, AdminApiError } from "../lib/adminApi";
import { LoadingState, ErrorState, StatusBadge, ConfirmDialog } from "../components/Common";

const PAGE_SIZE = 20;

export function Users() {
  const [rows, setRows] = useState<AdminUserRow[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState("");
  const [status, setStatus] = useState("all");
  const [sortBy, setSortBy] = useState("createdAt");
  const [sortDir, setSortDir] = useState<"asc" | "desc">("desc");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [feedback, setFeedback] = useState<string | null>(null);
  const [pendingAction, setPendingAction] = useState<{
    type: "suspend" | "unsuspend" | "delete";
    user: AdminUserRow;
  } | null>(null);

  const load = useCallback(() => {
    setLoading(true);
    setError(null);
    adminApi
      .listUsers({ search, status, sortBy, sortDir, page, pageSize: PAGE_SIZE })
      .then((result) => {
        setRows(result.rows);
        setTotal(result.total);
      })
      .catch((e: AdminApiError) => setError(e.message))
      .finally(() => setLoading(false));
  }, [search, status, sortBy, sortDir, page]);

  useEffect(() => {
    load();
  }, [load]);

  function toggleSort(field: string) {
    if (sortBy === field) {
      setSortDir(sortDir === "asc" ? "desc" : "asc");
    } else {
      setSortBy(field);
      setSortDir("desc");
    }
  }

  async function runAction() {
    if (!pendingAction) return;
    const { type, user } = pendingAction;
    setPendingAction(null);
    try {
      if (type === "suspend") await adminApi.suspendUser(user.id);
      if (type === "unsuspend") await adminApi.unsuspendUser(user.id);
      if (type === "delete") await adminApi.deleteUser(user.id);
      setFeedback(`${type === "unsuspend" ? "Unsuspended" : type === "suspend" ? "Suspended" : "Deleted"} ${user.email}`);
      load();
    } catch (e) {
      setFeedback(`Failed: ${(e as AdminApiError).message}`);
    }
  }

  const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE));

  return (
    <div className="space-y-4">
      <h1 className="text-xl font-semibold text-gray-900 dark:text-white">Users</h1>

      {feedback && (
        <div className="rounded-lg bg-brand-light px-3 py-2 text-sm text-brand dark:bg-brand/20 dark:text-white">
          {feedback}
        </div>
      )}

      <div className="flex flex-wrap gap-3">
        <input
          placeholder="Search by email or name..."
          value={search}
          onChange={(e) => {
            setPage(1);
            setSearch(e.target.value);
          }}
          className="min-w-[240px] flex-1 rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-brand focus:outline-none focus:ring-1 focus:ring-brand dark:border-gray-700 dark:bg-gray-800 dark:text-white"
        />
        <select
          value={status}
          onChange={(e) => {
            setPage(1);
            setStatus(e.target.value);
          }}
          className="rounded-lg border border-gray-300 px-3 py-2 text-sm dark:border-gray-700 dark:bg-gray-800 dark:text-white"
        >
          <option value="all">All statuses</option>
          <option value="active">Active</option>
          <option value="suspended">Suspended</option>
          <option value="deleted">Deleted</option>
        </select>
      </div>

      {error && <ErrorState message={error} />}
      {loading ? (
        <LoadingState />
      ) : (
        <div className="overflow-x-auto rounded-2xl border border-gray-200 bg-white shadow-sm dark:border-gray-800 dark:bg-gray-900">
          <table className="min-w-full text-sm">
            <thead>
              <tr className="border-b border-gray-200 text-left text-xs font-medium uppercase text-gray-500 dark:border-gray-800 dark:text-gray-400">
                <Th label="Email" field="email" sortBy={sortBy} sortDir={sortDir} onClick={toggleSort} />
                <th className="px-4 py-3">Display name</th>
                <th className="px-4 py-3">Status</th>
                <th className="px-4 py-3">Confirmed</th>
                <Th label="Created" field="createdAt" sortBy={sortBy} sortDir={sortDir} onClick={toggleSort} />
                <Th
                  label="Last sign-in"
                  field="lastSignInAt"
                  sortBy={sortBy}
                  sortDir={sortDir}
                  onClick={toggleSort}
                />
                <th className="px-4 py-3 text-right">Actions</th>
              </tr>
            </thead>
            <tbody>
              {rows.length === 0 && (
                <tr>
                  <td colSpan={7} className="px-4 py-8 text-center text-gray-400">
                    No users match these filters.
                  </td>
                </tr>
              )}
              {rows.map((u) => (
                <tr
                  key={u.id}
                  className="border-b border-gray-100 last:border-0 dark:border-gray-800"
                >
                  <td className="px-4 py-3">
                    <Link to={`/users/${u.id}`} className="font-medium text-brand hover:underline">
                      {u.email ?? "(no email)"}
                    </Link>
                    {u.isAdmin && (
                      <span className="ml-2 rounded-full bg-brand-light px-2 py-0.5 text-xs font-medium text-brand dark:bg-brand/20">
                        admin
                      </span>
                    )}
                  </td>
                  <td className="px-4 py-3 text-gray-600 dark:text-gray-300">
                    {u.displayName ?? "—"}
                  </td>
                  <td className="px-4 py-3">
                    <StatusBadge status={u.status} />
                  </td>
                  <td className="px-4 py-3 text-gray-600 dark:text-gray-300">
                    {u.emailConfirmed ? "Yes" : "No"}
                  </td>
                  <td className="px-4 py-3 text-gray-600 dark:text-gray-300">
                    {new Date(u.createdAt).toLocaleDateString()}
                  </td>
                  <td className="px-4 py-3 text-gray-600 dark:text-gray-300">
                    {u.lastSignInAt ? new Date(u.lastSignInAt).toLocaleDateString() : "Never"}
                  </td>
                  <td className="px-4 py-3 text-right">
                    <div className="flex justify-end gap-2">
                      {u.status === "suspended" ? (
                        <button
                          onClick={() => setPendingAction({ type: "unsuspend", user: u })}
                          className="rounded-lg border border-gray-300 px-2.5 py-1 text-xs font-medium text-gray-700 hover:bg-gray-50 dark:border-gray-700 dark:text-gray-200 dark:hover:bg-gray-800"
                        >
                          Unsuspend
                        </button>
                      ) : (
                        u.status !== "deleted" && (
                          <button
                            onClick={() => setPendingAction({ type: "suspend", user: u })}
                            className="rounded-lg border border-amber-300 px-2.5 py-1 text-xs font-medium text-amber-700 hover:bg-amber-50 dark:border-amber-800 dark:text-amber-300"
                          >
                            Suspend
                          </button>
                        )
                      )}
                      {u.status !== "deleted" && (
                        <button
                          onClick={() => setPendingAction({ type: "delete", user: u })}
                          className="rounded-lg border border-red-300 px-2.5 py-1 text-xs font-medium text-red-700 hover:bg-red-50 dark:border-red-800 dark:text-red-300"
                        >
                          Delete
                        </button>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      <div className="flex items-center justify-between text-sm text-gray-500 dark:text-gray-400">
        <span>
          {total} user{total === 1 ? "" : "s"} · page {page} of {totalPages}
        </span>
        <div className="flex gap-2">
          <button
            disabled={page <= 1}
            onClick={() => setPage((p) => Math.max(1, p - 1))}
            className="rounded-lg border border-gray-300 px-3 py-1.5 disabled:opacity-40 dark:border-gray-700"
          >
            Previous
          </button>
          <button
            disabled={page >= totalPages}
            onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
            className="rounded-lg border border-gray-300 px-3 py-1.5 disabled:opacity-40 dark:border-gray-700"
          >
            Next
          </button>
        </div>
      </div>

      <ConfirmDialog
        open={pendingAction !== null}
        title={
          pendingAction?.type === "delete"
            ? "Delete this user?"
            : pendingAction?.type === "suspend"
              ? "Suspend this user?"
              : "Unsuspend this user?"
        }
        description={
          pendingAction?.type === "delete"
            ? `${pendingAction.user.email} will be permanently signed out and their display name removed. This is not immediately reversible from the UI.`
            : pendingAction?.type === "suspend"
              ? `${pendingAction?.user.email} will be immediately signed out and blocked from signing in again until unsuspended.`
              : `${pendingAction?.user.email} will be able to sign in again.`
        }
        confirmLabel={
          pendingAction?.type === "delete"
            ? "Delete"
            : pendingAction?.type === "suspend"
              ? "Suspend"
              : "Unsuspend"
        }
        danger={pendingAction?.type !== "unsuspend"}
        onConfirm={runAction}
        onCancel={() => setPendingAction(null)}
      />
    </div>
  );
}

function Th({
  label,
  field,
  sortBy,
  sortDir,
  onClick,
}: {
  label: string;
  field: string;
  sortBy: string;
  sortDir: "asc" | "desc";
  onClick: (field: string) => void;
}) {
  const active = sortBy === field;
  return (
    <th
      className="cursor-pointer select-none px-4 py-3"
      onClick={() => onClick(field)}
    >
      {label} {active && (sortDir === "asc" ? "↑" : "↓")}
    </th>
  );
}
