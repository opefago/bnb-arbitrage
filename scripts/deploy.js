const {ethers} = require("hardhat")


async function main() {

    const [deployer] = await ethers.getSigners();

    console.log("Deploying contracts with the account:", deployer.address);
    
    console.log("account balance: ", (await deployer.getBalance()).toString());


    
    const ArbitrageFactory = await ethers.getContractFactory("Arbitrage");

    const arbitrage = await ArbitrageFactory.deploy();

    // await arbitrage.deployed();

    console.log("Arbitrage deployed to: ", arbitrage.address);
}

main()
    .then(()=> process.exit(0))
    .catch(err => {
        console.error(err);
        process.exit(1);
    })