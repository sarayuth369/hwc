import { useEffect, useState, useCallback } from "react";
import { adminApi, AuditLogRow, AdminApiError } from "../lib/adminApi";
import { LoadingState, ErrorState } from "../components/Common";

const PAGE_SIZE = 25;

export function AuditLog() {
  const [rows, setRows] = useState<AuditLogRow[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [action, setAction] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(() => {
    setLoading(true);
    setError(null);
    adminApi
      .listAuditLog({ page, pageSize: PAGE_SIZE, action: action || undefined })
      .then((r) => {
        setRows(r.rows);
        setTotal(r.total);
      })
      .catch((e: AdminApiError) => setError(e.message))
      .finally(() => setLoading(false));
  }, [page, action]);

  useEffect(() => {
    load();
  }, [load]);

  const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE));

  return (
    <div className="space-y-4">
      <h1 className="text-xl font-semibold text-gray-900 dark:text-white">Audit Log</h1>

      <input
        placeholder="Filter by action (e.g. user.suspend)..."
        value={action}
        onChange={(e) => {
          setPage(1);
          setAction(e.target.value);
        }}
        className="w-full max-w-sm rounded-lg border border-gray-300 px-3 py-2 text-sm dark:border-gray-700 dark:bg-gray-800 dark:text-white"
      />

      {error && <ErrorState message={error} />}
      {loading ? (
        <LoadingState />
      ) : (
        <div className="overflow-x-auto rounded-2xl border border-gray-200 bg-white shadow-sm dark:border-gray-800 dark:bg-gray-900">
          <table className="min-w-full text-sm">
            <thead>
              <tr className="border-b border-gray-200 text-left text-xs font-medium uppercase text-gray-500 dark:border-gray-800 dark:text-gray-400">
                <th className="px-4 py-3">Action</th>
                <th className="px-4 py-3">Target</th>
                <th className="px-4 py-3">Admin</th>
                <th className="px-4 py-3">When</th>
              </tr>
            </thead>
            <tbody>
              {rows.length === 0 && (
                <tr>
                  <td colSpan={4} className="px-4 py-8 text-center text-gray-400">
                    No audit entries match this filter.
                  </td>
                </tr>
              )}
              {rows.map((r) => (
                <tr key={r.id} className="border-b border-gray-100 last:border-0 dark:border-gray-800">
                  <td className="px-4 py-3 font-medium text-gray-900 dark:text-white">{r.action}</td>
                  <td className="px-4 py-3 text-gray-600 dark:text-gray-300">
                    {r.targetType}
                    {r.targetId ? ` · ${r.targetId}` : ""}
                  </td>
                  <td className="px-4 py-3 text-gray-600 dark:text-gray-300">{r.adminUserId}</td>
                  <td className="px-4 py-3 text-gray-600 dark:text-gray-300">
                    {new Date(r.createdAt).toLocaleString()}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      <div className="flex items-center justify-between text-sm text-gray-500 dark:text-gray-400">
        <span>
          {total} entries · page {page} of {totalPages}
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
    </div>
  );
}
