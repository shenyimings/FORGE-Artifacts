// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SuperfinePlatformTopup is Ownable {
    address public platform;
    address[] private _whitelistedCurrencies;
    mapping(address => bool) private _isCurrencyWhitelisted;

    event PlatformToppedUp(string id, address currency, uint256 amount);

    constructor(address platform_) Ownable() {
        platform = platform_;
    }

    function getWhitelistedCurrencies()
        external
        view
        returns (address[] memory)
    {
        return _whitelistedCurrencies;
    }

    function whitelistCurrencies(
        address[] memory currencies,
        bool[] memory isWhitelisteds
    ) external onlyOwner {
        require(
            currencies.length == isWhitelisteds.length,
            "SuperfinePlatformTopup: lengths mismatch"
        );
        for (uint256 i = 0; i < currencies.length; i++)
            if (isWhitelisteds[i]) {
                if (!_isCurrencyWhitelisted[currencies[i]]) {
                    _isCurrencyWhitelisted[currencies[i]] = true;
                    _whitelistedCurrencies.push(currencies[i]);
                }
            } else {
                if (_isCurrencyWhitelisted[currencies[i]]) {
                    _isCurrencyWhitelisted[currencies[i]] = false;
                    for (uint256 j = 0; j < _whitelistedCurrencies.length; j++)
                        if (_whitelistedCurrencies[j] == currencies[i]) {
                            _whitelistedCurrencies[j] = _whitelistedCurrencies[
                                _whitelistedCurrencies.length - 1
                            ];
                            _whitelistedCurrencies.pop();
                            break;
                        }
                }
            }
    }

    function topup(
        string memory id,
        address currency,
        uint256 amount
    ) external {
        require(
            _isCurrencyWhitelisted[currency],
            "SuperfinePlatformTopup: currency not supported"
        );
        bool success = IERC20(currency).transferFrom(
            msg.sender,
            platform,
            amount
        );
        require(success, "SuperfinePlatformTopup: failed to top up money");
        emit PlatformToppedUp(id, currency, amount);
    }
}
