import { Navigate, Outlet } from "react-router-dom";
import { useAuth } from "../contexts/AuthContext";

export function ProtectedRoute() {
  const { loading, session, isAdmin } = useAuth();

  if (loading) {
    return (
      <div className="flex h-screen items-center justify-center text-gray-500 dark:text-gray-400">
        Loading...
      </div>
    );
  }

  if (!session) return <Navigate to="/login" replace />;
  if (isAdmin === false) return <Navigate to="/unauthorized" replace />;

  return <Outlet />;
}
