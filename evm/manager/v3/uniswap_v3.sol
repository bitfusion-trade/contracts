// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "https://github.com/bitfusion-trade/contracts/evm/manager/base_manager.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

contract UniswapV3Manager is BaseManager {
    ISwapRouter public immutable swapRouter;
    uint24 public poolFee;

    constructor(
        address _pool,
        address _swapRouter,
        uint8 _baseTokenMark,
        address _wrappedNative
    ) BaseManager(_pool, _baseTokenMark, _wrappedNative) {
        swapRouter = ISwapRouter(_swapRouter);
        poolFee = IUniswapV3Pool(_pool).fee();
    }

    function fetchTokensFromPool(address _pool)
        internal
        view
        override
        returns (address _token0, address _token1)
    {
        _token0 = IUniswapV3Pool(_pool).token0();
        _token1 = IUniswapV3Pool(_pool).token1();
    }

    function tradeV3(
        TokenType _from,
        TokenType _to,
        uint256 _amount,
        uint256 _limit
    ) external onlyWhitelisted returns (uint256 amountOut) {
        require(_from != _to, "Cannot swap A to A");

        tokens[_from].approve(address(swapRouter), _amount);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: address(tokens[_from]),
                tokenOut: address(tokens[_to]),
                fee: poolFee,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: _amount,
                amountOutMinimum: _limit,
                sqrtPriceLimitX96: 0
            });

        amountOut = swapRouter.exactInputSingle(params);
    }
}