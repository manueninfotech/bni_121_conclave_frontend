// Public files follow Vite's base: "/" locally, "/conclave/" on manuen.com.
export const asset = (path) => `${import.meta.env.BASE_URL}${path}`
