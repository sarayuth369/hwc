import { ComingSoon } from "../components/Common";

export function Notifications() {
  return (
    <div className="space-y-4">
      <h1 className="text-xl font-semibold text-gray-900 dark:text-white">Notifications</h1>
      <ComingSoon
        title="Notification management"
        description="HWC ships real local (on-device) wellness reminders today, but there is no server-driven/broadcast notification system yet — that needs FCM/APNs plus a Worker-side trigger, neither of which exists."
      />
    </div>
  );
}

export function Subscriptions() {
  return (
    <div className="space-y-4">
      <h1 className="text-xl font-semibold text-gray-900 dark:text-white">Subscriptions</h1>
      <ComingSoon
        title="Billing & subscriptions"
        description="No payment provider is configured for HWC. Every account is on the free tier by design (SubscriptionRepository's default implementation) — this screen will show real plan/billing data once a provider is wired up, never fabricated numbers before then."
      />
    </div>
  );
}

export function AiUsage() {
  return (
    <div className="space-y-4">
      <h1 className="text-xl font-semibold text-gray-900 dark:text-white">AI / Usage</h1>
      <ComingSoon
        title="Per-user AI usage"
        description="The Worker's chat/insight/image routes don't write any usage log today, so there is nothing real to show here yet. Adding this means a usage_events table and a write on each AI call — a backend change, not an admin-UI-only one."
      />
    </div>
  );
}
