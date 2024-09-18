import { defineConfig } from "vite";

export default defineConfig({
  base: "/github-follow-manager/",
  build: {
    rollupOptions: {
      output: {
        manualChunks(id) {
          if (id.includes("node_modules")) {
            return "vendor";
          }
        },
      },
    },
  },
});
