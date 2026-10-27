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
});
