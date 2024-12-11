// wrapper.js
(async () => {
    const module = await import('./src/AcidTokenTest.js');
    
    // Copy all exports to the global object
    Object.entries(module).forEach(([key, value]) => {
        global[key] = value;
    });

    console.log('require.js preloaded and exports added to global scope! 🛠️');

    // Start a Node.js REPL, for testing 😊
    const repl = await import('node:repl');
    repl.start({});
})();
