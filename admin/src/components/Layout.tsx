import { NavLink, Outlet } from "react-router-dom";
import { useAuth } from "../contexts/AuthContext";

const NAV_ITEMS = [
  { to: "/", label: "Dashboard", end: true },
  { to: "/users", label: "Users" },
  { to: "/ai-usage", label: "AI / Usage" },
  { to: "/audit-log", label: "Audit Log" },
  { to: "/notifications", label: "Notifications" },
  { to: "/subscriptions", label: "Subscriptions" },
  { to: "/settings", label: "Settings" },
];

export function Layout() {
  const { session, signOut } = useAuth();

  return (
    <div className="flex h-screen bg-gray-50 dark:bg-gray-950">
      <aside className="hidden w-56 shrink-0 flex-col border-r border-gray-200 bg-white dark:border-gray-800 dark:bg-gray-900 md:flex">
        <div className="flex h-16 items-center gap-2 px-5">
          <div className="h-7 w-7 rounded-lg bg-brand" />
          <span className="text-lg font-semibold text-gray-900 dark:text-white">HWC Admin</span>
        </div>
        <nav className="flex-1 space-y-1 px-3 py-2">
          {NAV_ITEMS.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              end={item.end}
              className={({ isActive }) =>
                `block rounded-lg px-3 py-2 text-sm font-medium transition-colors ${
                  isActive
                    ? "bg-brand-light text-brand dark:bg-brand/20 dark:text-white"
                    : "text-gray-600 hover:bg-gray-100 dark:text-gray-300 dark:hover:bg-gray-800"
                }`
              }
            >
              {item.label}
            </NavLink>
          ))}
        </nav>
      </aside>

      <div className="flex flex-1 flex-col overflow-hidden">
        <header className="flex h-16 items-center justify-between border-b border-gray-200 bg-white px-4 dark:border-gray-800 dark:bg-gray-900 md:px-6">
          <span className="text-sm text-gray-500 dark:text-gray-400 md:hidden font-semibold">
            HWC Admin
          </span>
          <div className="ml-auto flex items-center gap-4">
            <span className="text-sm text-gray-600 dark:text-gray-300">{session?.user.email}</span>
            <button
              onClick={() => signOut()}
              className="rounded-lg border border-gray-300 px-3 py-1.5 text-sm font-medium text-gray-700 hover:bg-gray-50 dark:border-gray-700 dark:text-gray-200 dark:hover:bg-gray-800"
            >
              Log out
            </button>
          </div>
        </header>

        <main className="flex-1 overflow-y-auto p-4 md:p-6">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
