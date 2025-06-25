/**
 * Webpack Configuration for Lambda Function
 * Optimizes bundle size and performance for AWS Lambda deployment
 */

const path = require("path");
const webpack = require("webpack");

module.exports = (env, argv) => {
  const isProduction = argv.mode === "production";

  return {
    target: "node",
    mode: isProduction ? "production" : "development",
    entry: {
      index: "./src/index.js",
      server: "./src/server.js",
    },
    output: {
      path: path.resolve(__dirname, "dist"),
      filename: "[name].js",
      libraryTarget: "commonjs2",
      clean: true,
    },
    externals: {
      // AWS SDK is provided by Lambda runtime
      "aws-sdk": "aws-sdk",
      // Node.js built-ins
      crypto: "crypto",
      https: "https",
      http: "http",
      fs: "fs",
      path: "path",
      os: "os",
      util: "util",
      events: "events",
      stream: "stream",
      buffer: "buffer",
      url: "url",
      querystring: "querystring",
    },
    resolve: {
      extensions: [".js", ".json"],
      alias: {
        "@": path.resolve(__dirname, "src"),
      },
    },
    module: {
      rules: [
        {
          test: /\.js$/,
          exclude: /node_modules/,
          use: {
            loader: "babel-loader",
            options: {
              presets: [
                [
                  "@babel/preset-env",
                  {
                    targets: {
                      node: "18",
                    },
                    modules: "commonjs",
                  },
                ],
              ],
              plugins: [
                "@babel/plugin-proposal-object-rest-spread",
                "@babel/plugin-transform-async-to-generator",
              ],
            },
          },
        },
        {
          test: /\.json$/,
          type: "json",
        },
      ],
    },
    plugins: [
      new webpack.DefinePlugin({
        "process.env.NODE_ENV": JSON.stringify(
          isProduction ? "production" : "development"
        ),
        "process.env.BUILD_TIME": JSON.stringify(new Date().toISOString()),
        "process.env.BUILD_VERSION": JSON.stringify(
          process.env.npm_package_version || "1.0.0"
        ),
      }),
      new webpack.BannerPlugin({
        banner: "#!/usr/bin/env node",
        raw: true,
        entryOnly: false,
      }),
      // Ignore optional dependencies that might cause issues
      new webpack.IgnorePlugin({
        resourceRegExp: /^cardinal$/,
      }),
      new webpack.IgnorePlugin({
        resourceRegExp: /^encoding$/,
      }),
    ],
    optimization: {
      minimize: isProduction,
      splitChunks: {
        chunks: "all",
        cacheGroups: {
          vendor: {
            test: /[\\/]node_modules[\\/]/,
            name: "vendors",
            chunks: "all",
            enforce: true,
          },
          common: {
            name: "common",
            chunks: "all",
            minChunks: 2,
            enforce: true,
          },
        },
      },
    },
    devtool: isProduction ? "source-map" : "inline-source-map",
    stats: {
      colors: true,
      modules: false,
      chunks: false,
      chunkModules: false,
      entrypoints: false,
    },
    performance: {
      hints: isProduction ? "warning" : false,
      maxEntrypointSize: 5 * 1024 * 1024, // 5MB
      maxAssetSize: 5 * 1024 * 1024, // 5MB
    },
    node: {
      __dirname: false,
      __filename: false,
    },
  };
};
