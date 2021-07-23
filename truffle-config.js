require('dotenv').config();
const HDWalletProvider = require("@truffle/hdwallet-provider");

//Account credentials from which our contract will be deployed
const mnemonic = process.env.MNEMONIC;

//API key of your Datahub account for Avalanche Fuji test network
const APIKEY = process.env.APIKEY;

module.exports = {

  networks: {
    fuji: {
      provider: function () {
        return new HDWalletProvider({
          mnemonic,
          // providerOrUrl: `https://avalanche--fuji--rpc.datahub.figment.io/apikey/${APIKEY}/ext/bc/C/rpc`,
          providerOrUrl: `https://api.avax-test.network/ext/bc/C/rpc`,
          chainId: "0xa869"
        })
      },
      network_id: "*",
      gas: 8000000,
      gasPrice: 225000000000,
      skipDryRun: true,
      timeoutBlocks: 70,  // # of blocks before a deployment times out  (minimum/default: 50)
    },
    mainnet: {
      provider: function () {
        return new HDWalletProvider({
          mnemonic,
          providerOrUrl: `https://api.avax.network/ext/bc/C/rpc`,
          chainId: 43114
        })
      },
      network_id: "*",
      gas: 8000000,
      gasPrice: 225000000000,
      skipDryRun: true,
      timeoutBlocks: 70,  // # of blocks before a deployment times out  (minimum/default: 50)
    },
  },

  // Set default mocha options here, use special reporters etc.
  mocha: {
    // timeout: 100000
  },

  // Configure your compilers
  compilers: {
    solc: {
      version: "0.8.0",    // Fetch exact version from solc-bin (default: truffle's version)
      // docker: true,        // Use "0.5.1" you've installed locally with docker (default: false)
      settings: {          // See the solidity docs for advice about optimization and evmVersion
        optimizer: {
          enabled: true,
          runs: 200
        },
        //  evmVersion: "byzantium"
      }
    }
  },

  // Truffle DB is currently disabled by default; to enable it, change enabled: false to enabled: true
  //
  // Note: if you migrated your contracts prior to enabling this field in your Truffle project and want
  // those previously migrated contracts available in the .db directory, you will need to run the following:
  // $ truffle migrate --reset --compile-all

  db: {
    enabled: false
  },

  plugins: ["truffle-contract-size"]
};
