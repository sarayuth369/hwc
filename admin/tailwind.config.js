/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  darkMode: "media",
  theme: {
    extend: {
      colors: {
        brand: {
          DEFAULT: "#0249fe",
          dark: "#0038c4",
          light: "#e8efff",
        },
      },
    },
  },
  plugins: [],
};
