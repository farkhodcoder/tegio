import adapter from '@sveltejs/adapter-vercel';
import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';

export default defineConfig({
  // Mumbay: Supabase bazasi bilan bir mintaqa, Toshkentga ham eng yaqini.
  plugins: [sveltekit({ adapter: adapter({ regions: ['bom1'] }) })],
  // config/brand.json monorepo ildizida turadi.
  server: { fs: { allow: ['../..'] } }
});
