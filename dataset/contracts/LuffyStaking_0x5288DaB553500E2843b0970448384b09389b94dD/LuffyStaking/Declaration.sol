// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

interface IERC20 {

    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
	
	function balanceOf(address account) external view returns (uint256);
}

abstract contract Declaration {

    uint40 constant ONE_DAY = 60 * 60 * 24;
    uint40 constant ONE_YEAR = ONE_DAY * 365;

    IERC20 public immutable LUFFY;

    constructor(
        address _immutableLuffy
    ) {
        LUFFY = IERC20(_immutableLuffy);
    }

}