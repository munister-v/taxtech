import tailwindcss from '@tailwindcss/vite';
import react from '@vitejs/plugin-react';
import path from 'path';
import {defineConfig, type Plugin} from 'vite';

// Starts the chunk the visitor needs in parallel with the entry script instead of after it: the banking app for
// someone signed in (a token in storage), the street map for everyone else.
function preloadByVisitor(): Plugin {
  return {
    name: 'preload-by-visitor',
    apply: 'build',
    transformIndexHtml: {
      order: 'post',
      handler(html, ctx) {
        const chunks = Object.values(ctx.bundle || {});
        const find = (re: RegExp) => chunks.find(c => c.type === 'chunk' && c.facadeModuleId && re.test(c.facadeModuleId))?.fileName;
        const app = find(/\/App\.tsx$/), map = find(/\/romeMapData\.ts$/);
        if (!app || !map) return html;
        const js = `try{var a=localStorage.getItem('army_bank_token'),l=document.createElement('link');l.rel='modulepreload';l.href='/'+(a?${JSON.stringify(app)}:${JSON.stringify(map)});document.head.appendChild(l)}catch(e){}`;
        return html.replace('</head>', `    <script>${js}</script>\n  </head>`);
      },
    },
  };
}

// Мобільний застосунок навчального банку. Збірка лягає поруч із сервером: Flask віддає її з кореня домену.
export default defineConfig({
  plugins: [react(), tailwindcss(), preloadByVisitor()],
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
