import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    // The API goes through the dev server, so web and API share one site and the session
    // cookie stays first party. The browser still sends Origin http://localhost:5173.
    proxy: {
      '/api': 'http://localhost:3010',
    },
  },
})
