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
        entryFileNames: "assets/[name]-[hash].js",
        chunkFileNames: "assets/[name]-[hash].js",
        assetFileNames: "assets/[name]-[hash].[ext]",
      },
      plugins: [
        {
          name: 'exclude-index-files',
          generateBundle(options, bundle) {
            for (const fileName of Object.keys(bundle)) {
              if (fileName.startsWith('assets/index-') && (fileName.endsWith('.js') || fileName.endsWith('.css'))) {
                delete bundle[fileName];
              }
            }
          }
        }
      ]
    },
  },
});
