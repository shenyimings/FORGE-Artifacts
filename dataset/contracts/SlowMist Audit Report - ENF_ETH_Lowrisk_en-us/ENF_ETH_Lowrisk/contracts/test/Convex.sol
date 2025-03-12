// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";

interface ConvexBoosterInterface {
    function poolInfo(uint256)
        external
        view
        returns (
            address,
            address,
            address,
            address,
            address,
            bool
        );

    function poolLength() external view returns (uint256);
}

interface ICurvePool {
    function get_lp_token_addr() external view returns (address);
}

contract ConvexTest {
    address convexBooster = 0xF403C135812408BFbE8713b5A23a04b3D48AAE31;

    constructor() {}

    function getPid(address lpToken) public view returns (uint256) {
        for (uint256 i = 0; i < ConvexBoosterInterface(convexBooster).poolLength(); i++) {
            (address lp_token, , , , , bool shutdown) = ConvexBoosterInterface(convexBooster).poolInfo(i);
            if (!shutdown && lp_token == lpToken) {
                return i;
            }
        }
        return 0;
    }
}
