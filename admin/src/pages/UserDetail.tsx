import { useEffect, useState } from "react";
import { useParams, useNavigate, Link } from "react-router-dom";
import { adminApi, AdminUserRow, AdminApiError } from "../lib/adminApi";
import { LoadingState, ErrorState, StatusBadge, ConfirmDialog } from "../components/Common";

export function UserDetail() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const [user, setUser] = useState<AdminUserRow | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [displayName, setDisplayName] = useState("");
  const [editing, setEditing] = useState(false);
  const [saving, setSaving] = useState(false);
  const [feedback, setFeedback] = useState<string | null>(null);
  const [pendingAction, setPendingAction] = useState<"suspend" | "unsuspend" | "delete" | null>(
    null
  );

  function load() {
    if (!id) return;
    adminApi
      .getUser(id)
      .then((u) => {
        setUser(u);
        setDisplayName(u.displayName ?? "");
      })
      .catch((e: AdminApiError) => setError(e.message));
  }

  useEffect(load, [id]);

  async function saveDisplayName() {
    if (!id) return;
    setSaving(true);
    try {
      const updated = await adminApi.updateUserDisplayName(id, displayName);
      setUser(updated);
      setEditing(false);
      setFeedback("Display name updated");
    } catch (e) {
      setFeedback(`Failed: ${(e as AdminApiError).message}`);
    } finally {
      setSaving(false);
    }
  }

  async function runAction() {
    if (!id || !pendingAction) return;
    const action = pendingAction;
    setPendingAction(null);
    try {
      if (action === "suspend") await adminApi.suspendUser(id);
      if (action === "unsuspend") await adminApi.unsuspendUser(id);
      if (action === "delete") {
        await adminApi.deleteUser(id);
        navigate("/users");
        return;
      }
      load();
    } catch (e) {
      setFeedback(`Failed: ${(e as AdminApiError).message}`);
    }
  }

  if (error) return <ErrorState message={error} />;
  if (!user) return <LoadingState label="Loading user..." />;

  return (
    <div className="max-w-2xl space-y-4">
      <Link to="/users" className="text-sm text-brand hover:underline">
        ← Back to users
      </Link>
      <h1 className="text-xl font-semibold text-gray-900 dark:text-white">
        {user.email ?? "(no email)"}
      </h1>

      {feedback && (
        <div className="rounded-lg bg-brand-light px-3 py-2 text-sm text-brand dark:bg-brand/20 dark:text-white">
          {feedback}
        </div>
      )}

      <div className="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm dark:border-gray-800 dark:bg-gray-900">
        <dl className="grid grid-cols-2 gap-4 text-sm">
          <div>
            <dt className="text-gray-500 dark:text-gray-400">Status</dt>
            <dd className="mt-1">
              <StatusBadge status={user.status} />
            </dd>
          </div>
          <div>
            <dt className="text-gray-500 dark:text-gray-400">Admin</dt>
            <dd className="mt-1 text-gray-900 dark:text-white">{user.isAdmin ? "Yes" : "No"}</dd>
          </div>
          <div>
            <dt className="text-gray-500 dark:text-gray-400">Email confirmed</dt>
            <dd className="mt-1 text-gray-900 dark:text-white">
              {user.emailConfirmed ? "Yes" : "No"}
            </dd>
          </div>
          <div>
            <dt className="text-gray-500 dark:text-gray-400">Created</dt>
            <dd className="mt-1 text-gray-900 dark:text-white">
              {new Date(user.createdAt).toLocaleString()}
            </dd>
          </div>
          <div>
            <dt className="text-gray-500 dark:text-gray-400">Last sign-in</dt>
            <dd className="mt-1 text-gray-900 dark:text-white">
              {user.lastSignInAt ? new Date(user.lastSignInAt).toLocaleString() : "Never"}
            </dd>
          </div>
          <div>
            <dt className="text-gray-500 dark:text-gray-400">Plan / subscription</dt>
            <dd className="mt-1 text-xs text-gray-400 dark:text-gray-500">
              Not available yet — no payment provider is configured for HWC
            </dd>
          </div>
        </dl>
      </div>

      <div className="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm dark:border-gray-800 dark:bg-gray-900">
        <h2 className="mb-3 text-sm font-semibold text-gray-900 dark:text-white">Display name</h2>
        {editing ? (
          <div className="flex gap-2">
            <input
              value={displayName}
              onChange={(e) => setDisplayName(e.target.value)}
              className="flex-1 rounded-lg border border-gray-300 px-3 py-2 text-sm dark:border-gray-700 dark:bg-gray-800 dark:text-white"
            />
            <button
              onClick={saveDisplayName}
              disabled={saving}
              className="rounded-lg bg-brand px-3 py-2 text-sm font-medium text-white hover:bg-brand-dark disabled:opacity-60"
            >
              Save
            </button>
            <button
              onClick={() => {
                setEditing(false);
                setDisplayName(user.displayName ?? "");
              }}
              className="rounded-lg border border-gray-300 px-3 py-2 text-sm dark:border-gray-700"
            >
              Cancel
            </button>
          </div>
        ) : (
          <div className="flex items-center justify-between">
            <span className="text-gray-700 dark:text-gray-300">{user.displayName ?? "—"}</span>
            <button
              onClick={() => setEditing(true)}
              className="text-sm text-brand hover:underline"
            >
              Edit
            </button>
          </div>
        )}
      </div>

      <p className="text-xs text-gray-400 dark:text-gray-500">
        Private health data (metrics, AI chat history) is intentionally not shown here — least
        privilege applies even to admins; this screen only exposes account/profile fields.
      </p>

      <div className="flex gap-3">
        {user.status === "suspended" ? (
          <button
            onClick={() => setPendingAction("unsuspend")}
            className="rounded-lg border border-gray-300 px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 dark:border-gray-700 dark:text-gray-200 dark:hover:bg-gray-800"
          >
            Unsuspend
          </button>
        ) : (
          user.status !== "deleted" && (
            <button
              onClick={() => setPendingAction("suspend")}
              className="rounded-lg border border-amber-300 px-3 py-2 text-sm font-medium text-amber-700 hover:bg-amber-50 dark:border-amber-800 dark:text-amber-300"
            >
              Suspend
            </button>
          )
        )}
        {user.status !== "deleted" && (
          <button
            onClick={() => setPendingAction("delete")}
            className="rounded-lg border border-red-300 px-3 py-2 text-sm font-medium text-red-700 hover:bg-red-50 dark:border-red-800 dark:text-red-300"
          >
            Delete
          </button>
        )}
      </div>

      <ConfirmDialog
        open={pendingAction !== null}
        title={
          pendingAction === "delete"
            ? "Delete this user?"
            : pendingAction === "suspend"
              ? "Suspend this user?"
              : "Unsuspend this user?"
        }
        description={
          pendingAction === "delete"
            ? "This user will be permanently signed out and their display name removed."
            : pendingAction === "suspend"
              ? "This user will be immediately signed out and blocked from signing in again."
              : "This user will be able to sign in again."
        }
        confirmLabel={
          pendingAction === "delete" ? "Delete" : pendingAction === "suspend" ? "Suspend" : "Unsuspend"
        }
        danger={pendingAction !== "unsuspend"}
        onConfirm={runAction}
        onCancel={() => setPendingAction(null)}
      />
    </div>
  );
}
