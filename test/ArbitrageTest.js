const {expect, assert} = require("chai");
const {ethers, waffle} = require("hardhat");
const {impersonateFundErc20} = require("../utils/utilities")
const {abi} = require("../artifacts/contracts/interfaces/IERC20.sol/IERC20.json")


const provider = waffle.provider;

describe("Arbitrage Contract", ()=>{
    let FLASHSWAP, BORROW_AMOUNT, FUND_AMOUNT, initialFundingHuman, txArbitrage, gasUsedusdd;
    const DECIMALS = 18;

    const BUSD_WHALE = "0xf977814e90da44bfa03b6295a0616a897441acec";
    const BUSD = "0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56";
    const WBNB = "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c";
    const CAKE = "0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82";
    const USDT = "0x55d398326f99059fF775485246999027B3197955";
    const CROX = "0x2c094F5A7D1146BB93850f629501eB749f6Ed491";

    const BASE_TOKEN_ADDRESS = BUSD;

    const tokenBase = new ethers.Contract(BASE_TOKEN_ADDRESS, abi, provider)

    beforeEach(async ()=>{
        [owner] = await ethers.getSigners();

        const whale_balance = await provider.getBalance(BUSD_WHALE);
        expect(whale_balance).not.equal("0");

        console.log(ethers.utils.formatUnits(whale_balance, DECIMALS))

        const arbFactory = await ethers.getContractFactory("Arbitrage");
        FLASHSWAP = await arbFactory.deploy();
        await FLASHSWAP.deployed();

        //Configure our borrowing
        const borrowAmountHuman = "1"
        BORROW_AMOUNT = ethers.utils.parseUnits(borrowAmountHuman, DECIMALS)

        initialFundingHuman = "100"
        FUND_AMOUNT = ethers.utils.parseUnits(initialFundingHuman, DECIMALS)

        //Fund our contract
        await impersonateFundErc20(tokenBase, BUSD_WHALE, FLASHSWAP.address, initialFundingHuman)
    })


    it("Ensure the contract is funded", async ()=>{
        const flashSwapBalance = await FLASHSWAP.getBalanceOfToken(BASE_TOKEN_ADDRESS);
        const flashSwapBalanceHuman = ethers.utils.formatUnits(flashSwapBalance, DECIMALS);
        
        expect(Number(flashSwapBalanceHuman)).equal(Number(initialFundingHuman))
    })

    it("Execute the arbitrage", async () => {
        txArbitrage = await FLASHSWAP.startArbitrage(BASE_TOKEN_ADDRESS, BORROW_AMOUNT)

        assert(txArbitrage);

        const contractBalanceBUSD = await FLASHSWAP.getBalanceOfToken(BUSD);
        const formatBalanceBUSD = Number(ethers.utils.formatUnits(contractBalanceBUSD, DECIMALS))
        console.log("Balance of BUSD: " + formatBalanceBUSD)


        const contractBalanceCROX = await FLASHSWAP.getBalanceOfToken(CROX);
        const formatBalanceCROX = Number(ethers.utils.formatUnits(contractBalanceCROX, DECIMALS))
        console.log("Balance of CROX: " + formatBalanceCROX)


        const contractBalanceCAKE = await FLASHSWAP.getBalanceOfToken(CAKE);
        const formatBalanceCAKE = Number(ethers.utils.formatUnits(contractBalanceCAKE, DECIMALS))
        console.log("Balance of CAKE: " + formatBalanceCAKE)
    })
    

});