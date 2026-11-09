import adapter from '@sveltejs/adapter-node';
import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';

export default defineConfig({
  plugins: [sveltekit({ adapter: adapter() })],
  // config/brand.json monorepo ildizida turadi.
  server: { fs: { allow: ['../..'] } }
});
