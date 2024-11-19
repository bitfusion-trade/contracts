// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

interface IERC20 {
    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);
}

contract Helper {

    function getUniswapPoolV2(address _pool)
        external
        view
        returns (
            address,
            uint8,
            string memory,
            address,
            uint8,
            string memory
        )
    {
        address token0Contract = IUniswapV2Pair(_pool).token0();
        address token1Contract = IUniswapV2Pair(_pool).token1();

        return (
            token0Contract,
            IERC20(token0Contract).decimals(),
            IERC20(token0Contract).symbol(),
            token1Contract,
            IERC20(token1Contract).decimals(),
            IERC20(token1Contract).symbol()
        );
    }

    function getUniswapPoolV3(address _pool)
        external
        view
        returns (
            address,
            uint8,
            string memory,
            address,
            uint8,
            string memory,
            uint24
        )
    {

        address token0Contract = IUniswapV3Pool(_pool).token0();
        address token1Contract = IUniswapV3Pool(_pool).token1();

        return (
            token0Contract,
            IERC20(token0Contract).decimals(),
            IERC20(token0Contract).symbol(),
            token1Contract,
            IERC20(token1Contract).decimals(),
            IERC20(token1Contract).symbol(),
            IUniswapV3Pool(_pool).fee()
        );
    }

    function getNativeBalances(address[] memory addresses)
        public
        view
        returns (uint256[] memory)
    {
        uint256[] memory balances = new uint256[](addresses.length);
        for (uint256 i = 0; i < addresses.length; i++) {
            balances[i] = addresses[i].balance;
        }
        return balances;
    }
}
