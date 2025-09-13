import { defineConfig } from 'vite';
import gleam from 'vite-gleam';

export default defineConfig({
  plugins: [gleam()],

  // Development server configuration
  server: {
    port: 1234, // Keep your existing port
    host: true,
    proxy: {
      '/api': {
        target: 'http://localhost:8000',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/api/, ''),
      }
    }
  },

  // Build configuration
  build: {
    outDir: 'dist',
    rollupOptions: {
      input: 'main.js',
      output: {
        entryFileNames: 'assets/app.js',
        chunkFileNames: 'assets/[name].js',
        assetFileNames: 'assets/[name].[ext]'
      }
    }
  },

  // Ensure Gleam target is JavaScript
  optimizeDeps: {
    exclude: ['gleam']
  }
});
