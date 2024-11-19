// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

// универсальный

import "https://github.com/bitfusion-trade/contracts/evm/manager/base_manager.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract UniswapV2Manager is BaseManager {
    IUniswapV2Router02 public immutable swapRouter;

    constructor(
        address _pool,
        address _swapRouter,
        uint8 _baseTokenMark,
        address _wrappedNative
    ) BaseManager(_pool, _baseTokenMark, _wrappedNative) {
        swapRouter = IUniswapV2Router02(_swapRouter);
    }

    function fetchTokensFromPool(address _pool)
        internal
        view
        override
        returns (address _token0, address _token1)
    {
        _token0 = IUniswapV2Pair(_pool).token0();
        _token1 = IUniswapV2Pair(_pool).token1();
    }

    function trade(
        TokenType _from,
        TokenType _to,
        TokenType _amount_given_in,
        uint256 amount,
        uint256 limit
    ) external onlyWhitelisted {
        require(_from != _to, "Cannot swap A to A");
        require(
            _amount_given_in == _from || _amount_given_in == _to,
            "Amount should be A or B"
        );

        uint256 deadline = block.timestamp + 10000;
        address[] memory path = new address[](2);

        bool fromExactToAny = (_amount_given_in == _from);
        bool fromTokenToToken = (_from == TokenType.Base &&
            _to == TokenType.Quote) ||
            (_from == TokenType.Quote && _to == TokenType.Base);
        bool fromTokenToNative = (_from == TokenType.Base &&
            _to == TokenType.Native) ||
            (_from == TokenType.Quote && _to == TokenType.Native);
        bool fromNativeToToken = (_from == TokenType.Native &&
            _to == TokenType.Base) ||
            (_from == TokenType.Native && _to == TokenType.Quote);

        path[0] = address(tokens[_from]);
        path[1] = address(tokens[_to]);

        if (fromTokenToToken || fromTokenToNative) {
            fromExactToAny
                ? tokens[_from].approve(address(swapRouter), amount)
                : tokens[_from].approve(address(swapRouter), limit);
        }

        if (fromTokenToToken) {
            fromExactToAny
                ? swapRouter.swapExactTokensForTokens(
                    amount,
                    limit,
                    path,
                    address(this),
                    deadline
                )
                : swapRouter.swapTokensForExactTokens(
                    amount,
                    limit,
                    path,
                    address(this),
                    deadline
                );
        }
        if (fromTokenToNative) {
            fromExactToAny
                ? swapRouter.swapExactTokensForETH(
                    amount,
                    limit,
                    path,
                    address(this),
                    deadline
                )
                : swapRouter.swapTokensForExactETH(
                    amount,
                    limit,
                    path,
                    address(this),
                    deadline
                );
        }
        if (fromNativeToToken) {
            fromExactToAny
                ? swapRouter.swapExactETHForTokens{value: limit}(
                    amount,
                    path,
                    address(this),
                    deadline
                )
                : swapRouter.swapETHForExactTokens{value: amount}(
                    limit,
                    path,
                    address(this),
                    deadline
                );
        }
    }
}
