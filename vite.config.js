import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';
import { resolve } from 'path';

export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: {
    alias: {
      '@': resolve(__dirname, 'src'),
      'next/link': resolve(__dirname, 'src/shims/next-link.tsx'),
      'next/navigation': resolve(__dirname, 'src/shims/next-navigation.ts'),
      'next/image': resolve(__dirname, 'src/shims/next-image.tsx'),
    },
  },
  server: {
    port: 5173,
    proxy: {
      '/api': 'http://localhost:3000',
      '/campaigns': 'http://localhost:3000',
    },
  },
  build: {
    rollupOptions: {
      input: {
        main: resolve(__dirname, 'index.html'),
        editorial: resolve(__dirname, 'editorial.html'),
      },
    },
  },
});
