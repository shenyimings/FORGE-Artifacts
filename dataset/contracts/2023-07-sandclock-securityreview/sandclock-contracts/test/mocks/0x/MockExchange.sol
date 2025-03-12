// SPDX-License-Identifier: MIT
pragma solidity >0.8.10;

import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

abstract contract MockExchange {
    mapping(uint160 => uint256) exchageRates;

    function setExchageRate(
        address _from,
        address _to,
        uint256 _rate // e18
    ) external {
        exchageRates[_getExchangeRateKey(_from, _to)] = _rate;
    }

    function getExchangeRate(address _from, address _to) public view returns (uint256) {
        uint256 exchageRate = exchageRates[_getExchangeRateKey(_from, _to)];
        return exchageRate > 0 ? exchageRate : 1e18;
    }

    function swapTokens(address _from, address _to, uint256 _amount) public payable {
        if (_to == address(0)) {
            payable(msg.sender).transfer((_amount * getExchangeRate(_from, _to)) / 1e18);
        } else {
            uint256 toMint = (_amount * getExchangeRate(_from, _to)) / 1e18;
            MockERC20(_to).mint(msg.sender, toMint);
        }

        if (_from == address(0)) {
            require(msg.value == _amount, "MockExchange: insufficient ETH");
        } else {
            MockERC20(_from).burn(msg.sender, _amount);
        }
    }

    function _getExchangeRateKey(address _from, address _to) internal pure returns (uint160) {
        return (uint160(_from) << 1) ^ uint160(_to);
    }
}
