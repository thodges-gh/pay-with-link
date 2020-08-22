const HDWalletProvider = require('@truffle/hdwallet-provider')

module.exports = {
  networks: {
    dev: {
      host: '127.0.0.1',
      port: 8545,
      network_id: '*',
    },
    live: {
      provider: () => new HDWalletProvider(process.env.MNEMONIC, process.env.RPC_URL),
      network_id: '*',
      skipDryRun: true,
    },
  },
  compilers: {
    solc: {
      version: '0.6.12',
      settings: {
       optimizer: {
         enabled: true,
         runs: 200,
       },
      }
    },
  },
}
