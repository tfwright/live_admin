const esbuild = require('esbuild')

// Decide which mode to proceed with
let mode = 'build'
process.argv.slice(2).forEach((arg) => {
  if (arg === '--watch') {
    mode = 'watch'
  } else if (arg === '--release') {
    mode = 'release'
  }
})

// Define esbuild options + extras for watch and deploy
let opts = {
  entryPoints: ['js/app.js'],
  bundle: true,
  logLevel: 'info',
  target: 'es2016',
  outdir: '../dist/js',
  define: {
    'process.env.LATENCY_SIM': process.env.LATENCY_SIM || "0",
  },
}
if (mode === 'watch') {
  opts = {
    sourcemap: 'inline',
    ...opts
  }
}
if (mode === 'release') {
  opts = {
    minify: true,
    ...opts
  }
}

;(async () => {
  const context = await esbuild.context(opts)

  if (mode === 'watch') {
    context.watch()
  } else {
    await context.rebuild()
    context.dispose()
  }
})()
