import { FormEvent, useState } from "react";
import { useAuth } from "../contexts/AuthContext";
import { ComingSoon } from "../components/Common";

export function Settings() {
  const { session, changePassword } = useAuth();
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [message, setMessage] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setMessage(null);
    if (newPassword.length < 8) {
      setMessage("Password must be at least 8 characters.");
      return;
    }
    if (newPassword !== confirmPassword) {
      setMessage("Passwords don't match.");
      return;
    }
    setSaving(true);
    const { error } = await changePassword(newPassword);
    setSaving(false);
    if (error) {
      setMessage(`Failed: ${error}`);
    } else {
      setMessage("Password updated.");
      setNewPassword("");
      setConfirmPassword("");
    }
  }

  return (
    <div className="max-w-2xl space-y-6">
      <h1 className="text-xl font-semibold text-gray-900 dark:text-white">Settings</h1>

      <section className="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm dark:border-gray-800 dark:bg-gray-900">
        <h2 className="mb-1 text-sm font-semibold text-gray-900 dark:text-white">Admin Account</h2>
        <p className="mb-4 text-sm text-gray-500 dark:text-gray-400">{session?.user.email}</p>

        <form onSubmit={handleSubmit} className="space-y-3">
          <div>
            <label className="mb-1 block text-sm font-medium text-gray-700 dark:text-gray-300">
              New password
            </label>
            <input
              type="password"
              value={newPassword}
              onChange={(e) => setNewPassword(e.target.value)}
              className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm dark:border-gray-700 dark:bg-gray-800 dark:text-white"
              autoComplete="new-password"
            />
          </div>
          <div>
            <label className="mb-1 block text-sm font-medium text-gray-700 dark:text-gray-300">
              Confirm new password
            </label>
            <input
              type="password"
              value={confirmPassword}
              onChange={(e) => setConfirmPassword(e.target.value)}
              className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm dark:border-gray-700 dark:bg-gray-800 dark:text-white"
              autoComplete="new-password"
            />
          </div>
          {message && (
            <p className="text-sm text-gray-600 dark:text-gray-300">{message}</p>
          )}
          <button
            type="submit"
            disabled={saving}
            className="rounded-lg bg-brand px-4 py-2 text-sm font-semibold text-white hover:bg-brand-dark disabled:opacity-60"
          >
            {saving ? "Saving..." : "Change password"}
          </button>
        </form>

        <p className="mt-4 text-xs text-gray-400 dark:text-gray-500">
          Multi-factor authentication is not enabled yet. This login flow (Supabase Auth
          email/password, verified server-side on every privileged call) doesn't need to change
          to add it later — it's an additive step in front of the same session.
        </p>
      </section>

      <ComingSoon
        title="AI configuration"
        description="Model/provider selection and safety-ruleset controls live in the Worker's own config today (AI_PROVIDER, SAFETY_RULESET_VERSION env vars) — no admin UI wires to them yet."
      />
      <ComingSoon
        title="Feature flags & maintenance mode"
        description="No feature-flag store exists yet. This needs a small real table (e.g. app_config) the Worker reads and the Flutter app checks on launch — not built this pass to avoid a half-wired flag system with no consumer."
      />
      <ComingSoon
        title="Account policies & notification configuration"
        description="Password/session policy and notification delivery settings aren't configurable yet — HWC's local reminders and Supabase's own auth defaults are used as-is."
      />

      <section className="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm dark:border-gray-800 dark:bg-gray-900">
        <h2 className="mb-2 text-sm font-semibold text-gray-900 dark:text-white">
          About / System
        </h2>
        <dl className="space-y-1 text-sm text-gray-600 dark:text-gray-300">
          <div>Admin Manager v0.1.0</div>
          <div>Worker: {import.meta.env.VITE_WORKER_BASE_URL}</div>
        </dl>
      </section>
    </div>
  );
}
