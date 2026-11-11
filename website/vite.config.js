import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { resolve } from 'node:path'

// Four pages, one app: the landing page plus the support, privacy and terms
// pages that the stores link to. Each HTML file mounts src/main.jsx with its
// page name. Built with --base=/conclave/ for manuen.com/conclave.
export default defineConfig({
  plugins: [react()],
  build: {
    chunkSizeWarningLimit: 900,
    rollupOptions: {
      input: {
        main: resolve(import.meta.dirname, 'index.html'),
        privacy: resolve(import.meta.dirname, 'privacy/index.html'),
        terms: resolve(import.meta.dirname, 'terms/index.html'),
        support: resolve(import.meta.dirname, 'support/index.html'),
      },
    },
  },
  server: { allowedHosts: true },
})
