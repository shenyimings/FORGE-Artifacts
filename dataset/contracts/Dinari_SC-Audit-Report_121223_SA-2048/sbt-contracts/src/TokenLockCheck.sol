// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.22;

import {ITokenLockCheck} from "./ITokenLockCheck.sol";
import {IdShare} from "./IdShare.sol";
import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

interface IERC20Usdc {
    function isBlacklisted(address account) external view returns (bool);
}

interface IERC20Usdt {
    function isBlackListed(address account) external view returns (bool);
}

contract TokenLockCheck is ITokenLockCheck, Ownable {
    using Address for address;

    error NotContract();

    mapping(address => bytes4) public callSelector;

    constructor(address usdc, address usdt) Ownable(msg.sender) {
        if (usdc != address(0)) setCallSelector(usdc, IERC20Usdc.isBlacklisted.selector);
        if (usdt != address(0)) setCallSelector(usdt, IERC20Usdt.isBlackListed.selector);
    }

    function setCallSelector(address token, bytes4 selector) public onlyOwner {
        // if token is a contract, it must implement the selector
        if (selector != 0) _checkTransferLocked(token, address(this), selector);

        callSelector[token] = selector;
    }

    function setAsDShare(address token) external onlyOwner {
        // if token is a contract, it must implement the selector
        _checkTransferLocked(token, address(this), IdShare.isBlacklisted.selector);

        callSelector[token] = IdShare.isBlacklisted.selector;
    }

    function _checkTransferLocked(address token, address account, bytes4 selector) internal view returns (bool) {
        // assumes bool result
        return abi.decode(token.functionStaticCall(abi.encodeWithSelector(selector, account)), (bool));
    }

    function isTransferLocked(address token, address account) external view returns (bool) {
        bytes4 selector = callSelector[token];
        // if no selector is set, default to locked == false
        if (selector == 0) return false;

        return _checkTransferLocked(token, account, selector);
    }
}
