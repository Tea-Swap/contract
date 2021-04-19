const HDWalletProvider = require('truffle-hdwallet-provider-privkey');
require('dotenv').config()
const privateKey = [process.env.WALLET_PRIVATEKEY]
module.exports = {

  networks: {
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
      version: "0.8.3"
    }
  },
  plugins: [
    'truffle-plugin-verify'
  ],
  api_keys: {
    etherscan: process.env.BSCSCAN_API
  }
};
