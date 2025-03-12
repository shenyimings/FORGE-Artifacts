// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "../Interfaces/Interfaces.sol";
import "./PickleDepositToken.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract PickleTokenFactory {
    using Address for address;

    address public operator;

    constructor(address _operator) public {
        operator = _operator;
    }

    function CreateDepositToken(address _lptoken) external returns (address) {
        require(msg.sender == operator, "!authorized");

        PickleDepositToken dtoken = new PickleDepositToken(operator, _lptoken);
        return address(dtoken);
    }
}
