// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.6.6;

import "hardhat/console.sol";

import "./libraries/UniswapV2Library.sol";
import "./libraries/SafeERC20.sol";
import "./interfaces/IUniswapV2Router02.sol";
// import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IERC20.sol";

contract Arbitrage {
    address private owner;
    using SafeERC20 for IERC20;

    address private constant PANCAKE_FACTORY = 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;
    address private constant PANCAKE_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;

    address private constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address private constant BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    address private constant CAKE = 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82;
    address private constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    address private constant CROX = 0x2c094F5A7D1146BB93850f629501eB749f6Ed491;

    uint256 private deadlineThreshold =300;
    uint256 private constant MAX_INT = 115792089237316195423570985008687907853269984665640564039457584007913129639935;

    constructor() public {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(owner == msg.sender);
        _;
    }

    
    function fundContract(address _owner, address _token, uint256 _amount) public {
        IERC20(_token).transferFrom(_owner, address(this), _amount);
    }

    function getBalanceOfToken(address _address) public view returns (uint256) {
        return IERC20(_address).balanceOf(address(this));
    }

    //initiate arbitrage
    function startArbitrage(address _tokenBorrow, uint256 _amount) external {
        IERC20(BUSD).safeApprove(address(PANCAKE_ROUTER), MAX_INT);
        IERC20(USDT).safeApprove(address(PANCAKE_ROUTER), MAX_INT);
        IERC20(CROX).safeApprove(address(PANCAKE_ROUTER), MAX_INT);
        IERC20(CAKE).safeApprove(address(PANCAKE_ROUTER), MAX_INT);

        address pair = IUniswapV2Factory(PANCAKE_FACTORY).getPair(_tokenBorrow, WBNB);

        require(pair != address(0), "Pool does not exist");

        address token0 = IUniswapV2Pair(pair).token0();
        address token1 = IUniswapV2Pair(pair).token1();

 
    
        uint256 amount0Out = _tokenBorrow == token0 ? _amount : 0;
        uint256 amount1Out = _tokenBorrow == token1 ? _amount : 0;

        //Passing data as bytes so that the 'swap' function knows its a flashloan
        bytes memory data = abi.encode(_tokenBorrow, _amount, msg.sender);

        //Execute the initial swap to get the loan
        IUniswapV2Pair(pair).swap(amount0Out, amount1Out, address(this), data);
    }

    function executeTrade( address _from, address _to, uint256 _amountIn) private returns (uint256) {
         address pair = IUniswapV2Factory(PANCAKE_FACTORY).getPair(_from, _to);
         require(pair != address(0), "Pool does not exist");

         //Swap tokens: Get amount out
         address[] memory path = new address[](2);
         path[0] = _from;
         path[1] = _to;

         uint256 amountRequired = IUniswapV2Router01(PANCAKE_ROUTER).getAmountsOut(_amountIn, path)[1];

         console.log("Amount required ", amountRequired);

        
         uint deadline = block.timestamp + deadlineThreshold;

         //execute swap
         uint256 amountReceived = IUniswapV2Router01(PANCAKE_ROUTER).swapExactTokensForTokens(_amountIn, amountRequired, path, address(this), deadline)[1];

         console.log("Amount received ", amountReceived);

         require(amountReceived > 0, "Aborted tx: Trade returned zero");

         return amountReceived;
    }

    function checkProfitability(uint256 _input, uint256 _output) private pure  returns(bool) {
        return _output > _input;
    }

    function pancakeCall(address _sender, uint256 _amount0, uint256 _amount1, bytes calldata _data) external {
        address token0 = IUniswapV2Pair(msg.sender).token0();
        address token1 = IUniswapV2Pair(msg.sender).token1();

        address pair = IUniswapV2Factory(PANCAKE_FACTORY).getPair(token0, token1);

        require(msg.sender == pair, "The sender needs to match the pair");
        require(_sender == address(this), "The sender needs to match this contract");

        (address tokenBorrow, uint256 amount, address myAddress) = abi.decode(_data, (address, uint256, address));


        //Calculate the amount to repay plus fee
        uint256 fee = ((amount * 3)/ 997) + 1;
        uint256 amountToRepay = amount + fee;

        // Do Arbitrage
        //!!!!!!!!!!!!!
        uint256 loanAmount = _amount0 > 0 ?  _amount0: _amount1;

        uint256 trade1AcquiredCoin = executeTrade(BUSD, CROX, loanAmount);
        uint256 trade2AcquiredCoin = executeTrade(CROX, CAKE, trade1AcquiredCoin);
        uint256 trade3AcquiredCoin = executeTrade(CAKE, BUSD, trade2AcquiredCoin);



        //PAY YourSELF
        bool profCheck = checkProfitability(amountToRepay, trade3AcquiredCoin);

        require(profCheck, "Arbitrage not profitable");

        IERC20 otherToken = IERC20(BUSD);
        otherToken.transfer(myAddress, trade3AcquiredCoin-amountToRepay);



        //Repay loan
        IERC20(tokenBorrow).transfer(pair, amountToRepay);

    }


    //Dual dDex arbitrage

    function estimatePricesOnExchanges(address _router1, address _router2, address _token0, address _token1, uint256 _amountIn) external view returns (uint256) {
        uint256 amtBack1 = getAmountOutMin(_router1, _token0, _token1, _amountIn);
		uint256 amtBack2 = getAmountOutMin(_router2, _token1, _token0, amtBack1);
		return amtBack2;
    }

    function dualDexTrade(address _router1, address _router2, address _token1, address _token2, uint256 _amount) external onlyOwner {
        uint startBalance = IERC20(_token1).balanceOf(address(this));
        uint token2InitialBalance = IERC20(_token2).balanceOf(address(this));
        swap(_router1,_token1, _token2,_amount);
        uint token2Balance = IERC20(_token2).balanceOf(address(this));
        uint tradeableAmount = token2Balance - token2InitialBalance;
        swap(_router2,_token2, _token1,tradeableAmount);
        uint endBalance = IERC20(_token1).balanceOf(address(this));
        require(endBalance > startBalance, "Trade Reverted, No Profit Made");
    }

    function swap(address router, address _tokenIn, address _tokenOut, uint256 _amount) private {
		IERC20(_tokenIn).approve(router, _amount);
		address[] memory path;
		path = new address[](2);
		path[0] = _tokenIn;
		path[1] = _tokenOut;
		uint deadline = block.timestamp + deadlineThreshold;
		IUniswapV2Router01(router).swapExactTokensForTokens(_amount, 1, path, address(this), deadline);
	}

    function getAmountOutMin(address router, address _tokenIn, address _tokenOut, uint256 _amount) public view returns (uint256) {
		address[] memory path;
		path = new address[](2);
		path[0] = _tokenIn;
		path[1] = _tokenOut;
		uint256[] memory amountOutMins = IUniswapV2Router01(router).getAmountsOut(_amount, path);
		return amountOutMins[path.length -1];
	}
}