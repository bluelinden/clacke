import { defineConfig } from "rollup";
// A Rollup plugin which locates modules using the Node resolution algorithm
// A Rollup plugin to convert CommonJS modules to ES6, so they can be included in a Rollup bundle
import commonjs from "@rollup/plugin-commonjs";
// Use the latest JS features in your Rollup bundle
// Minifies the bundle

// CSS
// Enable the PostCSS preprocessor
import postcss from "rollup-plugin-postcss";
// // Use @import to include other CSS files
// import atImport from "postcss-import";
// Use the latest CSS features in your Rollup bundle
import postcssPresetEnv from "postcss-preset-env";
// Use tailwind
import tailwind from "@tailwindcss/postcss";

// Development: Enables a livereload server that watches for changes to CSS, JS, and Handlbars files
import { resolve } from "path";
import livereload from "rollup-plugin-livereload";
import terser from "@rollup/plugin-terser";


// Rollup configuration
export default defineConfig({
    input: "assets/js/index.js",
    output: {
        dir: "assets/built",
        sourcemap: false,
        format: "iife",
        plugins: [terser()],
        indent: false,
    },
    treeshake: false,
    plugins: [
        // commonjs({
        //     sourceMap: false,
        // }),
        // nodeResolve(),
        // babel({ babelHelpers: "bundled" }),
        postcss({
            extract: true,
            sourceMap: false,
            plugins: [postcssPresetEnv({}), tailwind({})],
            minimize: true,
            extensions: [".html", ".hbs", ".css"],
            exclude: ["assets/built"],
        }),
        process.env.BUILD !== "production" &&
            livereload({
                watch: resolve("."),
                extraExts: ["hbs"],
                exclusions: [resolve("node_modules")],
            }),
    ],
});
