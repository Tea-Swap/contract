const HDWalletProvider = require('truffle-hdwallet-provider-privkey');
require('dotenv').config()
const privateKey = [process.env.WALLET_PRIVATEKEY]
module.exports = {

  networks: {
    dev: {
      host: "127.0.0.1",     // Localhost (default: none)
            port: 7545,            // Standard Ethereum port (default: none)
            network_id: "*", 
    },
    testnet: {
      provider: () => new HDWalletProvider(privateKey, `https://data-seed-prebsc-1-s1.binance.org:8545`),
      network_id: 97,
      timeoutBlocks: 200,
      skipDryRun: true
    },
  },
  //
  compilers: {
    solc: {
      version: "0.8.4",
      settings: {
          optimizer: {
            enabled: true,
            runs: 5000,
          }
      }
      }
  },
  plugins: [
    'truffle-plugin-verify'
  ],
  api_keys: {
    bscscan: process.env.BSCSCAN_API
  }
};
