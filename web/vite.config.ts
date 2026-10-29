import tailwindcss from '@tailwindcss/vite';
import react from '@vitejs/plugin-react';
import path from 'path';
import {defineConfig} from 'vite';

// Мобільний застосунок навчального банку. Збірка лягає поруч із сервером: Flask віддає її з кореня домену.
export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, '.'),
    },
  },
  build: {
    outDir: '../server/frontend',
    emptyOutDir: true,
  },
  base: '/',
  server: {
    // API_PROXY=https://bank.munister.com.ua previews the landing with the live shop feed.
    proxy: {'/api': {target: process.env.API_PROXY || 'http://127.0.0.1:5050', changeOrigin: true}},
  },
});
