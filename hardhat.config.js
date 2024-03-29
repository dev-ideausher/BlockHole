require('@nomicfoundation/hardhat-toolbox');
require('@nomiclabs/hardhat-waffle');
require('@nomiclabs/hardhat-etherscan');
require('hardhat-deploy');
require('solidity-coverage');
require('hardhat-gas-reporter');
require('hardhat-contract-sizer');
require('dotenv').config();

// const GOERLI_RPC_URL =
//   process.env.GOERLI_RPC_URL ||
//   "https://eth-goerli.alchemyapi.io/v2/your-api-key";

// const PRIVATE_KEY = process.env.PRIVATE_KEY || "0x";

// const REPORT_GAS = process.env.REPORT_GAS || false;

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: '0.8.4',
  defaultNetwork: 'hardhat',
  networks: {
    hardhat: {
      chainId: 31337,
    },
    localhost: {
      chainId: 31337,
    },
    // goerli: {
    //   url: GOERLI_RPC_URL,
    //   accounts: PRIVATE_KEY !== undefined ? [PRIVATE_KEY] : [],
    //   //   accounts: {
    //   //     mnemonic: MNEMONIC,
    //   //   },
    //   saveDeployments: true,
    //   chainId: 5,
    // },

    // mainnet: {
    //   url: MAINNET_RPC_URL,
    //   accounts: PRIVATE_KEY !== undefined ? [PRIVATE_KEY] : [],
    //   //   accounts: {
    //   //     mnemonic: MNEMONIC,
    //   //   },
    //   saveDeployments: true,
    //   chainId: 1,
    // },
  },
  // gasReporter: {
  //   enabled: REPORT_GAS,
  //   currency: "USD",
  //   outputFile: "gas-report.txt",
  //   noColors: true,
  // coinmarketcap: process.env.COINMARKETCAP_API_KEY,
  // },
  // contractSizer: {
  //   runOnCompile: false,
  //   only: ["NFTMarketplace"],
  // },
  namedAccounts: {
    deployer: {
      default: 0, // here this will by default take the first account as deployer
      1: 0, // similarly on mainnet it will take the first account as deployer. Note though that depending on how hardhat network are configured, the account 0 on one network can be different than on another
    },
    player: {
      default: 1,
    },
  },
};
