/**
 * @type import('hardhat/config').HardhatUserConfig
 */
 require("@nomiclabs/hardhat-waffle");
 require("@nomiclabs/hardhat-ethers");
 require("dotenv").config()
module.exports = {
  solidity: {
    compilers: [
      {version: "0.8.0"},
      {version: "0.4.24"},
      {version: "0.5.0"},
      {version: "0.6.2"},
      {version: "0.6.6"},
    ]
  },
  networks: {
    hardhat: {
      forking: {
        url: "https://bsc-dataseed1.binance.org/",
      }
    },
    localhost : {
      url: "http://localhost:8545/",
      chainId: 31337,
      accounts : [process.env.PRIVATE_LOCAL_KEY],
    },
    testnet : {
      url: "https://data-seed-prebsc-2-s1.binance.org:8545/",
      chainId: 97,
      accounts : [process.env.PRIVATE_DEV_KEY],
    },
    mainnet: {
      url: "https://bsc-dataseed1.binance.org/",
      chainId: 56,
      accounts : [process.env.PRIVATE_PROD_KEY],
    }
  }
};
