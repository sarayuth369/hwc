import { useEffect, useState } from "react";
import { adminApi, DashboardMetrics, AdminApiError } from "../lib/adminApi";
import { StatCard, LoadingState, ErrorState } from "../components/Common";

export function Dashboard() {
  const [data, setData] = useState<DashboardMetrics | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    adminApi
      .getDashboard()
      .then(setData)
      .catch((e: AdminApiError) => setError(e.message));
  }, []);

  if (error) return <ErrorState message={error} />;
  if (!data) return <LoadingState label="Loading dashboard..." />;

  return (
    <div className="space-y-6">
      <h1 className="text-xl font-semibold text-gray-900 dark:text-white">Dashboard</h1>

      <div className="grid grid-cols-2 gap-4 md:grid-cols-4">
        <StatCard label="Total users" value={data.totalUsers} />
        <StatCard label="Active" value={data.activeUsers} />
        <StatCard label="Suspended" value={data.suspendedUsers} />
        <StatCard label="Deleted" value={data.deletedUsers} />
        <StatCard label="Confirmed emails" value={data.confirmedUsers} />
        <StatCard label="Unconfirmed emails" value={data.unconfirmedUsers} />
        <StatCard label="New (7 days)" value={data.newUsersLast7Days} />
        <StatCard label="New (30 days)" value={data.newUsersLast30Days} />
      </div>

      <div className="grid gap-4 md:grid-cols-2">
        <div className="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm dark:border-gray-800 dark:bg-gray-900">
          <h2 className="mb-3 text-sm font-semibold text-gray-900 dark:text-white">
            Service status
          </h2>
          <div className="flex items-center justify-between py-1 text-sm">
            <span className="text-gray-500 dark:text-gray-400">Worker</span>
            <StatusDot ok={data.serviceStatus.worker === "ok"} />
          </div>
          <div className="flex items-center justify-between py-1 text-sm">
            <span className="text-gray-500 dark:text-gray-400">Supabase Admin API</span>
            <StatusDot ok={data.serviceStatus.supabaseAdminApi === "ok"} />
          </div>
          <div className="mt-3 flex items-center justify-between py-1 text-sm">
            <span className="text-gray-500 dark:text-gray-400">AI usage tracking</span>
            <span className="text-xs text-gray-400 dark:text-gray-500">Not available yet</span>
          </div>
        </div>

        <div className="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm dark:border-gray-800 dark:bg-gray-900">
          <h2 className="mb-3 text-sm font-semibold text-gray-900 dark:text-white">
            Recent admin activity
          </h2>
          {data.recentActivity.length === 0 ? (
            <p className="text-sm text-gray-400 dark:text-gray-500">No activity yet.</p>
          ) : (
            <ul className="space-y-2">
              {data.recentActivity.map((item, i) => (
                <li key={i} className="text-sm text-gray-600 dark:text-gray-300">
                  <span className="font-medium">{item.action}</span>
                  {item.targetId && <span className="text-gray-400"> · {item.targetId}</span>}
                  <span className="ml-2 text-xs text-gray-400">
                    {new Date(item.createdAt).toLocaleString()}
                  </span>
                </li>
              ))}
            </ul>
          )}
        </div>
      </div>

      <div className="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm dark:border-gray-800 dark:bg-gray-900">
        <h2 className="mb-2 text-sm font-semibold text-gray-900 dark:text-white">Quick actions</h2>
        <div className="flex flex-wrap gap-3">
          <a
            href="/users"
            className="rounded-lg bg-brand px-3 py-1.5 text-sm font-medium text-white hover:bg-brand-dark"
          >
            Manage users
          </a>
          <a
            href="/audit-log"
            className="rounded-lg border border-gray-300 px-3 py-1.5 text-sm font-medium text-gray-700 hover:bg-gray-50 dark:border-gray-700 dark:text-gray-200 dark:hover:bg-gray-800"
          >
            View audit log
          </a>
        </div>
      </div>
    </div>
  );
}

function StatusDot({ ok }: { ok: boolean }) {
  return (
    <span
      className={`inline-flex items-center gap-1.5 text-xs font-medium ${
        ok ? "text-green-700 dark:text-green-400" : "text-red-700 dark:text-red-400"
      }`}
    >
      <span className={`h-2 w-2 rounded-full ${ok ? "bg-green-500" : "bg-red-500"}`} />
      {ok ? "Operational" : "Error"}
    </span>
  );
}
