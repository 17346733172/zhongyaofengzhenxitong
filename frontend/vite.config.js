import { defineConfig, loadEnv } from "vite";
import react from "@vitejs/plugin-react";

// 开发服务器默认端口 5173，与 backend 的 DECOCTION_CORS_ORIGINS 默认值一致。
export default defineConfig(({ mode }) => {
  // 不带 VITE_ 前缀的网关认证只供 Node 开发代理使用，不注入浏览器。
  const env = loadEnv(mode, process.cwd(), "");
  const target = env.DECOCTION_DEV_API_TARGET || "http://127.0.0.1:8000";
  const auth = env.DECOCTION_DEV_HTTP_USERNAME
    ? `${env.DECOCTION_DEV_HTTP_USERNAME}:${env.DECOCTION_DEV_HTTP_PASSWORD || ""}`
    : undefined;
  const localOrigins = new Set(["http://127.0.0.1:5173", "http://localhost:5173"]);

  return {
    plugins: [react()],
    server: {
      host: "127.0.0.1",
      port: 5173,
      strictPort: true,
      proxy: {
        // 同源访问后端，避免浏览器跨域；需要真实跨域时改用 VITE_API_BASE
        "/api": { target, changeOrigin: true, auth },
        "/ws": {
          target,
          changeOrigin: true,
          auth,
          ws: true,
          configure(proxy) {
            proxy.on("proxyReqWs", (proxyReq, request) => {
              // 远程网关登记其自身来源；仅为本地开发页面转发该来源。
              if (env.DECOCTION_DEV_WS_ORIGIN && localOrigins.has(request.headers.origin)) {
                proxyReq.setHeader("origin", env.DECOCTION_DEV_WS_ORIGIN);
              }
            });
          },
        },
      },
    },
    build: { outDir: "dist", sourcemap: false },
  };
});
