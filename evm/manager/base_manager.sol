// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;
pragma abicoder v2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract BaseManager is Ownable {
    using SafeERC20 for IERC20;

    enum TokenType {
        Native,
        Base,
        Quote
    }

    mapping(address => bool) private whitelist;
    mapping(TokenType => IERC20) internal tokens;

    constructor(
        address _pool,
        uint8 _baseTokenMark,
        address _wrappedNative
    ) Ownable(msg.sender) {
        require(
            _baseTokenMark == 0 || _baseTokenMark == 1,
            "Invalid _baseTokenMark"
        );

        (address token0Address, address token1Address) = fetchTokensFromPool(_pool);

        tokens[TokenType.Base] = IERC20(_baseTokenMark == 0 ? token0Address : token1Address);
        tokens[TokenType.Quote] = IERC20(_baseTokenMark == 1 ? token0Address : token1Address);
        tokens[TokenType.Native] = IERC20(_wrappedNative);

        whitelist[msg.sender] = true;
    }

    function fetchTokensFromPool(address _pool)
        internal
        view
        virtual
        returns (address _token0, address _token1);

    receive() external payable {}

    modifier onlyWhitelisted() {
        require(whitelist[msg.sender], "Not whitelisted");
        _;
    }

    function _withdrawTokens(
        TokenType _tokenType,
        address _recipient,
        uint256 _amount
    ) internal {
        require(whitelist[_recipient], "Recipient is not whitelisted");
        require(_amount > 0, "Amount must be greater than 0");

        if (_tokenType == TokenType.Native) {
            (bool success, ) = _recipient.call{value: _amount}("");
            require(success, "Transfer failed");
            return;
        }

        tokens[_tokenType].safeTransfer(_recipient, _amount);
    }

    function _sendNativesToMany(
        address[] memory _recipients,
        uint256 _amountPerRecipient
    ) internal {
        uint256 totalAmount = _amountPerRecipient * _recipients.length;
        require(_amountPerRecipient > 0, "Amount must be greater than 0");
        require(
            totalAmount <= address(this).balance,
            "Insufficient manager balance"
        );
        for (uint128 i = 0; i < _recipients.length; i++) {
            _withdrawTokens(
                TokenType.Native,
                _recipients[i],
                _amountPerRecipient
            );
        }
    }

    function _whitelistWallets(address[] memory _wallets) internal {
        for (uint256 i = 0; i < _wallets.length; i++) {
            whitelist[_wallets[i]] = true;
        }
    }

    function _blockWallets(address[] memory _wallets) internal {
        for (uint256 i = 0; i < _wallets.length; i++) {
            whitelist[_wallets[i]] = false;
        }
    }

    function whitelistWallets(address[] calldata _wallets) external onlyOwner {
        _whitelistWallets(_wallets);
    }

    function blockWallets(address[] calldata _wallets) external onlyOwner {
        _blockWallets(_wallets);
    }

    function isWalletWhitelisted(
        address _wallet
    ) external view onlyOwner returns (bool) {
        return whitelist[_wallet];
    }

    function getBalances() external view returns (uint256, uint256, uint256) {
        return (
            address(this).balance,
            tokens[TokenType.Base].balanceOf(address(this)),
            tokens[TokenType.Quote].balanceOf(address(this))
        );
    }

    function getOwnerBalances()
        external
        view
        onlyOwner
        returns (uint256, uint256, uint256)
    {
        return (
            owner().balance,
            tokens[TokenType.Base].balanceOf(owner()),
            tokens[TokenType.Quote].balanceOf(owner())
        );
    }

    function sendNatives(
        address[] calldata _recipients,
        uint256 _amountPerRecipient
    ) external onlyOwner {
        _sendNativesToMany(_recipients, _amountPerRecipient);
    }

    function whitelistAndSendNatives(
        address[] calldata _recipients,
        uint256 _amountPerRecipient
    ) external onlyOwner {
        require(_recipients.length > 0, "Array must be non-empty");
        _whitelistWallets(_recipients);
        if (_amountPerRecipient != 0) {
            _sendNativesToMany(_recipients, _amountPerRecipient);
        }
    }

    function deposit(
        uint256 _baseAmount,
        uint256 _quoteAmount
    ) external payable onlyOwner {
        require(
            _baseAmount <= tokens[TokenType.Base].balanceOf(owner()),
            "Insufficient base balance"
        );
        require(
            _quoteAmount <= tokens[TokenType.Quote].balanceOf(owner()),
            "Insufficient quote balance"
        );
        if (_baseAmount != 0) {
            tokens[TokenType.Base].safeTransferFrom(owner(), address(this), _baseAmount);
        }
        if (_quoteAmount != 0) {
            tokens[TokenType.Quote].safeTransferFrom(owner(), address(this), _quoteAmount);
        }
    }

    function withdraw(
        uint256 _nativeAmount,
        uint256 _baseAmount,
        uint256 _quoteAmount
    ) external onlyOwner {
        require(
            _nativeAmount <= address(this).balance,
            "Insufficient native balance"
        );
        require(
            _baseAmount <= tokens[TokenType.Base].balanceOf(address(this)),
            "Insufficient base balance"
        );
        require(
            _quoteAmount <= tokens[TokenType.Quote].balanceOf(address(this)),
            "Insufficient quote balance"
        );
        if (_nativeAmount != 0) {
            _withdrawTokens(TokenType.Native, owner(), _nativeAmount);
        }
        if (_baseAmount != 0) {
            _withdrawTokens(TokenType.Base, owner(), _baseAmount);
        }
        if (_quoteAmount != 0) {
            _withdrawTokens(TokenType.Quote, owner(), _quoteAmount);
        }
    }

    function withdrawAll() external onlyOwner {
        uint256 nativeAmount = address(this).balance;
        uint256 baseAmount = tokens[TokenType.Base].balanceOf(address(this));
        uint256 quoteAmount = tokens[TokenType.Quote].balanceOf(address(this));
        require(
            (nativeAmount > 0) || (baseAmount > 0) || (quoteAmount > 0),
            "Manager is empty"
        );

        if (nativeAmount != 0) {
            _withdrawTokens(TokenType.Native, owner(), nativeAmount);
        }
        if (baseAmount != 0) {
            _withdrawTokens(TokenType.Base, owner(), baseAmount);
        }
        if (quoteAmount != 0) {
            _withdrawTokens(TokenType.Quote, owner(), quoteAmount);
        }
    }
}
