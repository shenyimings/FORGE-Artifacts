// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "../Interfaces/Interfaces.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract PicklePoolManager {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    address public constant gaugeProxy = address(0x2e57627ACf6c1812F99e274d0ac61B786c19E74f);

    address public operator;
    address public pools;

    constructor(address _pools) public {
        operator = msg.sender;
        pools = _pools;
    }

    function setOperator(address _operator) external {
        require(msg.sender == operator, "!auth");
        operator = _operator;
    }

    //revert control of adding  pools back to operator
    function revertControl() external {
        require(msg.sender == operator, "!auth");
        IPools(pools).setPoolManager(operator);
    }

    //add a new pickle pool to the system.
    //gauge must be on pickle's gaugeProxy, thus anyone can call
    function addPool(address _lptoken) external returns (bool) {
        require(_lptoken != address(0), "lptoken is 0");

        //get  gauge by lp token from gauge proxy
        address _gauge = IRegistry(gaugeProxy).getGauge(_lptoken);
        require(_gauge != address(0), "gauge is 0");

        bool gaugeExists = IPools(pools).gaugeMap(_gauge);
        require(!gaugeExists, "already registered");

        IPools(pools).addPicklePool(_lptoken, _gauge);

        return true;
    }

    function shutdownPool(uint256 _pid) external returns (bool) {
        require(msg.sender == operator, "!auth");

        IPools(pools).shutdownPool(_pid);
        return true;
    }
}
