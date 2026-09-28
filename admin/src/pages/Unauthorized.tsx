import { useAuth } from "../contexts/AuthContext";

export function Unauthorized() {
  const { signOut, session } = useAuth();
  return (
    <div className="flex h-screen items-center justify-center bg-gray-50 dark:bg-gray-950">
      <div className="max-w-md rounded-2xl border border-gray-200 bg-white p-8 text-center shadow-sm dark:border-gray-800 dark:bg-gray-900">
        <h1 className="mb-2 text-lg font-semibold text-gray-900 dark:text-white">
          Not an admin account
        </h1>
        <p className="mb-6 text-sm text-gray-600 dark:text-gray-400">
          {session?.user.email} is signed in, but this account doesn't have admin access.
          Contact whoever manages the HWC admin roster to be granted access.
        </p>
        <button
          onClick={() => signOut()}
          className="rounded-lg border border-gray-300 px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 dark:border-gray-700 dark:text-gray-200 dark:hover:bg-gray-800"
        >
          Log out
        </button>
      </div>
    </div>
  );
}
